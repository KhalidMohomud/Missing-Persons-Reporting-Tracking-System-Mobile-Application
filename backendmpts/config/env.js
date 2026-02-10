import { v2 as cloudinary } from 'cloudinary';
import dotenv from 'dotenv';

dotenv.config();

cloudinary.config({
    cloud_name: process.env.CLOUDINARY_NAME,
    api_key: process.env.CLOUDINARY_API_KEY,
    api_secret: process.env.CLOUDINARY_API_SECRET,
    // secure: true, // ensures HTTPS URLs
});
if (!process.env.CLOUDINARY_NAME) {
    console.error("Missing CLOUDINARY_CLOUD_NAME in .env file");
}


export const config = {

    port: process.env.PORT || 3000,
    // port: process.env.CLERK_PUBLISHABLE_KEY,
    // clerkSecretKey: process.env.CLERK_SECRET_KEY,
    cloudinary,
};


export const jwtSecret = process.env.JWT_SECRET;

