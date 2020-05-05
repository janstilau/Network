//
//  MCUploadManager.h
//  MCFriends
//
//  Created by Zhou Kang on 2017/6/1.
//  Copyright © 2017年 Moca Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

#define GIFMAXSIZE (20 * 1024 * 1024)
#define IMAGEMAXSIZE (2 * 1024 * 1024)

typedef NS_ENUM(NSUInteger, MCMediaType) {
    MCMediaTypePicture=0,
    MCMediaTypeAudio,
    MCMediaTypeVideo,
};

typedef NS_ENUM(NSUInteger, MCMediaScene) {
    MCMediaSceneAvatar=0,
    MCMediaSceneBGWall,
    MCMediaScenePhotoWall,
    MCMediaScenePost,
    MCMediaSceneReplyPost,
    MCMediaScenePostAudio = 12,
    MCMediaSceneReplyAudio = 13,
    MCMediaScenePostVideo = 22,
    MCMediaScenePostVideoCover = 24
};

@interface MCUploadItem : NSObject

@property (nonatomic, assign) MCMediaType mediaType;

@property (nonatomic, strong) NSData   *resourceData;        //等待上传的二进制源数据
@property (nonatomic, strong) NSString *filePath;            //等待上传的文件的路径
@property (nonatomic, strong) UIImage  *image;               //等待上传的照片
@property (nonatomic, strong) NSData   *compressData;        //等待上传的二进制压缩数据

@property (nonatomic, strong, readonly) NSString *mimeType;
@property (nonatomic, strong, readonly) NSString *cloundURLString;
@property (nonatomic, assign, readonly) CGFloat imageHeight;
@property (nonatomic, assign, readonly) CGFloat imageWidth;

@end

typedef void (^MCUploadProgressHandler)(CGFloat progress);
typedef void (^MCUploadCompleteHandler)(NSArray <MCUploadItem *> *results, NSError *error);

@interface MCUploadManager : NSObject

/**
 腾讯云直传

 @param sourceArray 数据源, 元素可以是 UIImage *, NSData *, NSString *fileLocalPath,
 @param progressHandler 进度回调
 @param completeHandler 上传完成回调
 @return 实例
 */
+ (instancetype)uploadWithSource:(NSArray<id> *)sourceArray
                 progressHandler:(MCUploadProgressHandler)progressHandler
                 completeHandler:(MCUploadCompleteHandler)completeHandler;
/**
 腾讯云直传

 @param sourceArray 数据源, 元素可以是 UIImage *, NSData *, NSString *fileLocalPath,
 @param mediaType 媒体类型
 @param scene 业务所在位置, 后端生成签名和路径需要据此区分文件夹
 @param progressHandler 进度回调
 @param completeHandler 上传完成回调
 @return 实例
 */
+ (instancetype)uploadWithSource:(NSArray<id> *)sourceArray
                       mediaType:(MCMediaType)mediaType
                     scene:(MCMediaScene)scene
                 progressHandler:(MCUploadProgressHandler)progressHandler
                 completeHandler:(MCUploadCompleteHandler)completeHandler;

@end
