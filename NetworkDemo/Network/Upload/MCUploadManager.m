//
//  MCUploadManager.m
//  MCFriends
//
//  Created by Zhou Kang on 2017/6/1.
//  Copyright © 2017年 Moca Inc. All rights reserved.
//

#import "MCUploadManager.h"

@interface MCUploadItem ()

@property (nonatomic, assign) NSInteger signRetryCount;       //获取签名失败重试次数
@property (nonatomic, assign) NSInteger uploadRetryCount;     //上传失败重试次数

@property (nonatomic, strong, readwrite) NSString *mimeType;
@property (nonatomic, strong, readwrite) NSString *cloundURLString;
@property (nonatomic, assign, readwrite) CGFloat imageHeight;
@property (nonatomic, assign, readwrite) CGFloat imageWidth;

@end

@implementation MCUploadItem

- (NSData *)resourceData {
    if (_resourceData) { return _resourceData; }
    NSData *fileData = nil;
    switch (_mediaType) {
        case MCMediaTypePicture:
            fileData = [self imageData];
            break;
        case MCMediaTypeAudio:
            fileData = [self audioData];
            break;
        case MCMediaTypeVideo:
            fileData = [self videoData];
            break;
        default:
            break;
    }
    if (fileData) { _resourceData = fileData; }
    return fileData;
}

- (NSData *)compressData { //只对图片做压缩处理
    if (_compressData) { return _compressData; }
    if (_mediaType != MCMediaTypePicture) { return [self resourceData]; }
    if ([self resourceData]) {
        _compressData = [self compressDataIfNeed:_resourceData];
    }
    return _compressData;
}

#pragma mark - Image

- (NSData *)imageData {
    UIImage *item_image = self.image;
    if (!item_image) { return nil; }
    return UIImageJPEGRepresentation(item_image, 1.f);
}

- (NSData *)compressDataIfNeed:(NSData *)imageData {
    // 20M 是腾讯云的限制. 2M 是业务需求限制
    // GIF:20M 其他图片:2M
    CGFloat kImageLimit = 2.f*1024*1024;
    SDImageFormat imageFormat = [NSData sd_imageFormatForImageData:imageData];
    if (imageFormat == SDImageFormatGIF) {
        kImageLimit = 20.f*1024*1024;
    }
    NSTimeInterval startInterval = [[NSDate date] timeIntervalSince1970] * 1000;
    UIImage *img = [UIImage imageWithData:imageData];
    if (imageData.length < kImageLimit) { return imageData; }
    NSData *compressedData = imageData;
    for (CGFloat i=0.78; i>0.5; i-=0.02) {
        @autoreleasepool {
            compressedData = UIImageJPEGRepresentation(img, i);
        }
        if (compressedData.length < kImageLimit) { break; };
    }
    NSTimeInterval endInterval = [[NSDate date] timeIntervalSince1970] * 1000;
    DLOG(@"图片压缩耗时:%.0fms, 最终上传图片大小：%@", endInterval - startInterval,
         [NSByteCountFormatter stringFromByteCount:compressedData.length countStyle:NSByteCountFormatterCountStyleBinary]);
    return compressedData;
}

- (UIImage *)image {
    if (_image) { return _image; }
    UIImage *image = [UIImage imageWithContentsOfFile:_filePath];
    if (image) { return image; }
    image = [UIImage imageWithData:_resourceData];
    if (image) { return image; }
    return nil;
}

- (CGFloat)imageWidth {
    return self.image.size.width;
}

- (CGFloat)imageHeight {
    return self.image.size.height;
}

#pragma mark - Audio

- (NSData *)audioData {
    NSData *filedata = [NSData dataWithContentsOfFile:_filePath];
    return filedata;
}

#pragma mark - Video

- (NSData *)videoData {
    NSData *filedata = [NSData dataWithContentsOfFile:_filePath];
    return filedata;
}

@end

@interface MCUploadManager ()

@property (nonatomic, assign) BOOL isCanceled;
@property (nonatomic, assign) BOOL isUploading;
@property (nonatomic, assign) CGFloat progress;
@property (nonatomic, strong) NSArray<MCUploadItem *> *allItems;
@property (nonatomic, strong) NSMutableArray<MCUploadItem *> *uploadingItems;
@property (nonatomic, strong) MCUploadItem *uploadingItem;
@property (nonatomic, strong) MCUploadProgressHandler progressHandler;
@property (nonatomic, strong) MCUploadCompleteHandler completeHandler;
@property (nonatomic, assign) MCMediaScene sceneType;
@property (nonatomic, strong) NSURLSessionUploadTask *currentTask;

@end

@implementation MCUploadManager

+ (instancetype)uploadWithSource:(NSArray<id> *)sourceArray
                 progressHandler:(MCUploadProgressHandler)progressHandler
                 completeHandler:(MCUploadCompleteHandler)completeHandler {
    return [self uploadWithSource:sourceArray
                        mediaType:MCMediaTypePicture
                      scene:MCMediaScenePost
                  progressHandler:progressHandler
                  completeHandler:completeHandler];
}

+ (instancetype)uploadWithSource:(NSArray<id> *)sourceArray
                       mediaType:(MCMediaType)mediaType
                     scene:(MCMediaScene)scene
                 progressHandler:(MCUploadProgressHandler)progressHandler
                 completeHandler:(MCUploadCompleteHandler)completeHandler {
    NSError *error = nil;
    NSArray *uploadItems = [self uploadItems:sourceArray mediaType:mediaType error:&error];
    if (error) {
        if (completeHandler) { completeHandler(nil, error); }
        return nil;
    }
    
    MCUploadManager *operation = [[self alloc] init];
    operation.uploadingItems = [NSMutableArray arrayWithArray:uploadItems];
    operation.allItems = uploadItems;
    operation.progressHandler = progressHandler;
    operation.completeHandler = completeHandler;
    operation.sceneType = scene;
    [operation start];
    [[NSNotificationCenter defaultCenter] addObserver:operation selector:@selector(cancelTask) name:Noti_CancelProgressTask object:nil];
    return operation;
}

+ (NSArray<MCUploadItem*>*)uploadItems:(NSArray *)resources
                             mediaType:(MCMediaType)mediaType
                                 error:(NSError *__autoreleasing*)error{
    NSMutableArray *resultM = [NSMutableArray arrayWithCapacity:resources.count];
    for (id obj in resources) {
        MCUploadItem *item = [[MCUploadItem alloc] init];
        item.mediaType = mediaType;
        item.mimeType = [self mimeTypeWithMediaType:mediaType];
        if ([obj isKindOfClass:[NSData class]]) {
            item.resourceData = obj;
        } else if ([obj isKindOfClass:[NSString class]]) {
            if (![[NSFileManager defaultManager] fileExistsAtPath:obj]) {
                *error = [NSError errorWithDomain:NSURLErrorDomain
                                             code:NSURLErrorResourceUnavailable userInfo:@{NSLocalizedDescriptionKey:@"文件路径不存在"}];
                break;
            } else {
                item.filePath = obj;
            }
        } else if ([obj isKindOfClass:[UIImage class]]) {
            item.image = obj;
        } else {
            *error = [NSError errorWithDomain:NSURLErrorDomain
                                         code:NSURLErrorResourceUnavailable userInfo:@{NSLocalizedDescriptionKey:@"提供的数据源不能为空"}];
            break;
        }
        [resultM addObject:item];
    }
    return resultM;
}

+ (NSString *)mimeTypeWithMediaType:(MCMediaType)mediaType {
    NSDictionary *mimeTypeMap = @{
        @(MCMediaTypePicture): @"image/jpeg",
        @(MCMediaTypeAudio): @"application/octet-stream",
        @(MCMediaTypeVideo): @"video/mp4"
    };
    if (![mimeTypeMap containsObjectForKey:@(mediaType)]) { return @"image/jpeg"; }
    return mimeTypeMap[@(mediaType)];
}

#pragma mark - Upload

- (void)start {
    if (_isCanceled) { return; }
    if (_isUploading) { return; }
    if (!_uploadingItems.count) {
        [self allResourceDidUploadSuccess];
        return;
    }
    MCUploadItem *aPreparedItem = [_uploadingItems firstObject];
    [self uploadResource:aPreparedItem];
}

- (void)cancelTask {
    if (_currentTask) {
        _isCanceled = YES;
        [_currentTask cancel];
        NSError *error = [NSError errorWithDomain:NSURLErrorDomain
            code:NSURLErrorCancelled
        userInfo:@{NSLocalizedDescriptionKey:@"上传已取消"}];
        
        if (_completeHandler) { _completeHandler(nil, error); }
    }
}

static const NSUInteger kMaxRetryCount = 3;

- (void)uploadResource:(MCUploadItem *)item {
    _uploadingItem = item;
    NSMutableURLRequest *request = [self requestForItem:item];
    DLOG(@"post request url:  %@",request.URL.absoluteString);
    
    void (^progressHandler)(NSProgress *) = ^(NSProgress *uploadProgress) {
        [self updateWithProgress:uploadProgress];
    };
    
    void (^completionHandler)(NSURLResponse *, id, NSError *) = ^(NSURLResponse *response, id responseObject, NSError *error) {
        [self completeUploadWithResponse:response resObj:responseObject error:error];
    };
    
    AFHTTPSessionManager *manager = [AFHTTPSessionManager manager];
    manager.responseSerializer = [UGJSONResponseSerializer serializer];
    manager.responseSerializer.acceptableContentTypes = nil;
    _currentTask = [manager uploadTaskWithStreamedRequest:request progress:progressHandler completionHandler:completionHandler];
    [_currentTask resume];
}

- (NSMutableURLRequest *)requestForItem:(MCUploadItem *)item {
    NSData *filedata = item.compressData;
    NSString *fileName = [NSString stringWithFormat:@"%@_%@.%@",
                          [NSDate serverDateString],
                          @(item.mediaType),
                          [self resourceExtension:item]];
    void (^formBlock)(id <AFMultipartFormData> formData) = ^(id<AFMultipartFormData> formData) {
        [formData appendPartWithFileData:filedata name:@"file" fileName:fileName mimeType:item.mimeType];
    };
    MCMediaType mediaType = item.mediaType;
    NSDictionary *params = @{
                             @"access_token": safeStr(_loginUser.accessToken),
                             @"type": @(mediaType).stringValue,
                             @"picture_type": @(_sceneType).stringValue,
                             @"timestamp": [NSDate serverDateString],
                             };
    AFHTTPRequestSerializer *serializer = [AFHTTPRequestSerializer serializer];
    NSMutableURLRequest *request = [serializer multipartFormRequestWithMethod:@"POST"
                                                                    URLString:url_upload_resource
                                                                   parameters:params
                                                    constructingBodyWithBlock:formBlock
                                                                        error:nil];
    return request;
}

- (void)updateWithProgress:(NSProgress *)uploadProgress {
    if (uploadProgress.totalUnitCount <= 0) { return; }
    CGFloat progress = uploadProgress.completedUnitCount*1.f / uploadProgress.totalUnitCount;
    DLOG(@"upload process: %.0f%% (%@/%@)",
        100*progress,
        @(uploadProgress.completedUnitCount),
        @(uploadProgress.totalUnitCount));
    dispatch_async(dispatch_get_main_queue(), ^{
        self.progress = progress;
    });
}

- (void)completeUploadWithResponse:(NSURLResponse* )response
                            resObj:(NSDictionary *)responseObject
                             error:(NSError*)error {
    _isUploading = NO;
    self.progress = 1;
    
    if (error) {
        [self reUploadRes:response resObj:responseObject error:error];
    } else {
        BOOL isBadDataFormat = ![responseObject isKindOfClass:[NSDictionary class]];
        if (isBadDataFormat) {
            error = [NSError errorWithDomain:NSURLErrorDomain
                                               code:NSURLErrorCannotDecodeContentData
                                           userInfo:@{NSLocalizedDescriptionKey:@"返回的数据格式不正确"}];
            !_completeHandler ?: _completeHandler(nil, error);
            return;
        }
        BOOL success = [responseObject[@"success"] boolValue];
        if (!success) {
            [self reUploadRes:response resObj:responseObject error:error];
            return;
        }
        DLOG(@"post responseObject:  %@", responseObject);
        _uploadingItem.cloundURLString = responseObject[@"data"][@"path"];
        [self.uploadingItems removeObject:_uploadingItem];
        _uploadingItem = nil;
        [self start];
    }
}

- (void)reUploadRes:(NSURLResponse* )response
             resObj:(NSDictionary *)responseObject
              error:(NSError*)error {
    ELOG(@"post request url:  %@", response.URL.absoluteString);
    ELOG(@"post responseObject:  %@", responseObject);
    ELOG(@"post error :  %@", error.localizedDescription);
    _uploadingItem.uploadRetryCount += 1;
    if (_uploadingItem.uploadRetryCount >= kMaxRetryCount) {
        if (!_completeHandler) { return; }
        if (!error) {
            NSMutableDictionary *dictM = [NSMutableDictionary dictionaryWithCapacity:1];
            dictM[NSLocalizedDescriptionKey] = @"资源上传失败, 请稍后重试";
            NSString *msg = responseObject[@"data"][@"message"];
            if (!isEmptyString(msg)) { dictM[NSLocalizedDescriptionKey] = msg;}
            error = [NSError errorWithDomain:@"com.upload.moca" code:0 userInfo:dictM];
        }
        _completeHandler(nil, error);
    } else {
        WLOG(@"资源上传失败！即将进行第%zd次重试", _uploadingItem.uploadRetryCount);
        [self start];
    }
}

- (void)setProgress:(CGFloat)progress {
    _progress = progress;
    if (!_progressHandler) { return; }
    NSInteger total = _allItems.count;
    NSInteger uploaded = _allItems.count - _uploadingItems.count;
    CGFloat newMultiplier = MAX(CGFLOAT_MIN, total?((uploaded+floor(_progress*100)/100.f)/total):1);
    _progressHandler(newMultiplier);
}

#pragma mark - Uploaded

- (void)allResourceDidUploadSuccess {
    if (!_completeHandler) { return; }
    _completeHandler(_allItems, nil);
}

#pragma mark - MimeType

- (NSString *)resourceExtension:(MCUploadItem *)item {
    NSDictionary *extensionMap = @{
        @(MCMediaTypeAudio): @"mp3",
        @(MCMediaTypeVideo): @"mp4",
    };
    if ([extensionMap containsObjectForKey:@(item.mediaType)]) {
        return extensionMap[@(item.mediaType)];
    }
    return [self imageExtension:item.resourceData];
}

- (NSString *)imageExtension:(NSData *)data {
    uint8_t c;
    [data getBytes:&c length:1];
    switch (c) {
        case 0xFF:
            return @"jpeg";
        case 0x89:
            return @"png";
        case 0x47:
            return @"gif";
        case 0x49:
        case 0x4D:
            return @"tiff";
    }
    return @"jpeg";
}

- (void)dealloc {
    DLOG(@"dealloc 释放类 %@",  NSStringFromClass([self class]));
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

@end
