import { Plugin } from 'vite';
import multer from 'multer';
import { v2 as cloudinary } from 'cloudinary';

const upload = multer({ storage: multer.memoryStorage() });

export function uploadPlugin(): Plugin {
  // Configure Cloudinary
  cloudinary.config({
    cloud_name: process.env.CLOUDINARY_CLOUD_NAME,
    api_key: process.env.CLOUDINARY_API_KEY,
    api_secret: process.env.CLOUDINARY_API_SECRET,
  });

  return {
    name: 'vite-plugin-upload',
    configureServer(server) {
      server.middlewares.use('/api/upload', (req, res, next) => {
        if (req.method !== 'POST') {
          res.statusCode = 405;
          res.end('Method not allowed');
          return;
        }

        // Handle multipart form data
        upload.single('image')(req as any, res as any, async (err: any) => {
          if (err) {
            res.statusCode = 400;
            res.end(JSON.stringify({ error: 'Upload error' }));
            return;
          }

          const file = (req as any).file;
          if (!file) {
            res.statusCode = 400;
            res.end(JSON.stringify({ error: 'No file provided' }));
            return;
          }

          try {
            // Upload to Cloudinary
            const result = await new Promise((resolve, reject) => {
              const uploadStream = cloudinary.uploader.upload_stream(
                {
                  folder: 'ouest-app/avatars',
                  resource_type: 'auto',
                },
                (error, result) => {
                  if (error) reject(error);
                  else resolve(result);
                }
              );
              uploadStream.end(file.buffer);
            });

            res.setHeader('Content-Type', 'application/json');
            res.end(JSON.stringify({ url: (result as any).secure_url }));
          } catch (error) {
            console.error('Upload error:', error);
            res.statusCode = 500;
            res.end(JSON.stringify({ error: 'Upload failed' }));
          }
        });
      });
    },
  };
}

