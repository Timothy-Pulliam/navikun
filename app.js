// const express = require('express');
// const morgan = require('morgan');
// const dotenv = require('dotenv');
// const path = require('path');
// const nunjucks = require('nunjucks');
// ES6 imports
import express from 'express';
import morgan from 'morgan';
import dotenv from 'dotenv';
import path from 'path';
import { fileURLToPath } from 'url';
import nunjucks from 'nunjucks';
import { BedrockRuntimeClient, InvokeModelCommand } from "@aws-sdk/client-bedrock-runtime";
import { invokeClaude } from './claude.js';

dotenv.config();
const app = express();

// Bedrock
const client = new BedrockRuntimeClient({ region: "REGION" });

// Use morgan middleware for logging
if (process.env.NODE_ENV === 'development') {
    app.use(morgan('dev'));
}

// support JSON-enconded bodies
app.use(express.json());
// to support URL-encoded bodies
app.use(express.urlencoded({ extended: true }));
// Templating
const __dirname = path.dirname(fileURLToPath(import.meta.url));
app.set('views', path.join(__dirname, 'views'));
app.set('view engine', 'njk')
app.use(express.static('static'));
nunjucks.configure('views', {
    autoescape: true,
    express: app
});

app.get('/', (req, res) => {
    res.render('index');
})

app.post('/', async (req, res) => {
    const prompt = req.body.prompt
    console.log(prompt);
    const completion = await invokeClaude(prompt);
    //console.log(completion);
    //res.render('index');
    res.json({ 'response': completion });
})

const EXPRESS_PORT = process.env.EXPRESS_PORT;
const EXPRESS_HOST = process.env.EXPRESS_HOST;
app.listen(EXPRESS_PORT, EXPRESS_HOST, () => {
    console.log(`Express app listening at ${EXPRESS_HOST}:${EXPRESS_PORT}`);
});
