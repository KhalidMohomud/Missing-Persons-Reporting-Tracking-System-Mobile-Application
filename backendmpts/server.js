
import express from 'express';
import { config } from "./config/env.js";
import userRouter from "./router/users.route.js";
import reportRouter from "./router/reports.route.js";
import cors from "cors";
import helmet from "helmet";
import { clerkMiddleware } from '@clerk/express'

const app = express();

// Increase body size limit to handle large base64 images (50MB)
app.use(express.json({ limit: '50mb' }));
app.use(express.urlencoded({ extended: true, limit: '50mb' }));
app.use(cors());
app.use(helmet());
app.use(clerkMiddleware());

// app.get('/', (req, res) => {
//     res.send('Missing Persons API is running...');
// });

// 3. Routes (Ensure NO SPACES in the string)
app.use("/api/v1", userRouter);
app.use("/api/v1", reportRouter);

app.listen(config.port, () =>
    console.log(`Server running on http://localhost:${config.port}`)
);
