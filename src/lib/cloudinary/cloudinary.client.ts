import { v2 as cloudinary } from "cloudinary";

interface CloudinaryUploadResult {
  secure_url: string;
}

cloudinary.config({
  cloud_name: process.env.CLOUDINARY_CLOUD_NAME,
  api_key: process.env.CLOUDINARY_API_KEY,
  api_secret: process.env.CLOUDINARY_API_SECRET,
});

export class CloundiaryClient {
  static async uploadImage(imageBuffer: Buffer) {
    try {
      const imageResult: CloudinaryUploadResult = await new Promise(
        (resolve, reject) => {
          const uploadStream = cloudinary.uploader.upload_stream(
            { resource_type: "auto" },
            (
              error: any,
              result:
                | CloudinaryUploadResult
                | PromiseLike<CloudinaryUploadResult>
                | undefined
            ) => {
              if (error) {
                reject(error);
              } else if (!result) {
                reject("Result not received");
              } else {
                resolve(result);
              }
            }
          );
          uploadStream.end(imageBuffer);
        }
      );
      return imageResult.secure_url;
    } catch (err) {
      console.error(err, "Error uploading image to cloudinary");

      throw new Error("Error uploading image to Cloudinary");
    }
  }
}
