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
import { auth } from 'express-openid-connect';
import helmet from 'helmet';

dotenv.config();
const app = express();
app.use(helmet());
app.disable('x-powered-by');
// Bedrock
const client = new BedrockRuntimeClient({ region: "REGION" });

// Use morgan middleware for logging
const NODE_ENV = process.env.NODE_ENV || 'production';
if (NODE_ENV === 'development') {
    app.use(morgan('dev'));
}

console.log(process.env.AUTH0_DOMAIN)
console.log(process.env.AUTH0_CLIENT_ID)

const config = {
    authRequired: false,
    auth0Logout: true,
    secret: process.env.AUTH0_CLIENT_SECRET,
    baseURL: 'https://www.navikun.com',
    clientID: process.env.AUTH0_CLIENT_ID,
    issuerBaseURL: process.env.AUTH0_DOMAIN
};
// auth router attaches /login, /logout, and /callback routes to the baseURL
app.use(auth(config));

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



// req.isAuthenticated is provided from the auth router
// app.get('/', (req, res) => {
//     res.send(req.oidc.isAuthenticated() ? 'Logged in' : 'Logged out');
// });

app.post('/', async (req, res) => {
    const prompt = req.body.prompt
    console.log(prompt);
    const completion = await invokeClaude(prompt);
    //console.log(completion);
    //res.render('index');
    res.json({ 'response': completion });
})

// app.get('/signin', (req, res) => {
//     res.render('signin');
// })

// req.isAuthenticated is provided from the auth router
app.get('/test', (req, res) => {
    res.send(req.oidc.isAuthenticated() ? 'Logged in' : 'Logged out');
});


// custom 404
app.use((req, res, next) => {
    res.status(404).send("Sorry can't find that!")
})

// custom error handler
app.use((err, req, res, next) => {
    console.error(err.stack)
    res.status(500).send('Something broke!')
})

const EXPRESS_PORT = process.env.EXPRESS_PORT || 8080;
const EXPRESS_HOST = process.env.EXPRESS_HOST || '0.0.0.0';
app.listen(EXPRESS_PORT, EXPRESS_HOST, () => {
    console.log(`Express app listening at ${EXPRESS_HOST}:${EXPRESS_PORT}`);
});
