// ES6 imports
import express from 'express';
import morgan from 'morgan';
import dotenv from 'dotenv';
import path from 'path';
import { fileURLToPath } from 'url';
import fs from 'fs';
import nunjucks from 'nunjucks';
import { invokeClaude } from './claude.js';
import auth0 from 'express-openid-connect';
const { auth, requiresAuth } = auth0;
import helmet from 'helmet';
import cors from 'cors';

const app = express();
app.use(cors());
app.use(helmet());
// disable identifying header
app.disable('x-powered-by');

const __dirname = path.dirname(fileURLToPath(import.meta.url));

const NODE_ENV = process.env.NODE_ENV || 'production';
if (NODE_ENV === 'development') {
    console.log('Running in Dev mode\n')
    app.use(morgan('dev'));
    dotenv.config({ path: path.join(__dirname, 'dev.env'), override: true, debug: true });
} else {
    dotenv.config({ path: path.join(__dirname, '.env'), override: true });
    // Log only 4xx and 5xx responses to console
    app.use(morgan('dev', {
        skip: function (req, res) { return res.statusCode < 400 }
    }));

    // Log all requests to access.log
    app.use(morgan('common', {
        stream: fs.createWriteStream(path.join(__dirname, 'access.log'), { flags: 'a' })
    }));
}

let auth0_config = {
    authRequired: false,
    auth0Logout: true,
    secret: process.env.AUTH0_CLIENT_SECRET,
    baseURL: process.env.AUTH0_BASE_URL,
    clientID: process.env.AUTH0_CLIENT_ID,
    issuerBaseURL: process.env.AUTH0_DOMAIN
};
// auth router attaches /login, /logout, and /callback routes to the baseURL
app.use(auth(auth0_config));

// support JSON-enconded bodies
app.use(express.json());
// to support URL-encoded bodies
app.use(express.urlencoded({ extended: true }));
// Templating
app.set('views', path.join(__dirname, 'views'));
app.set('view engine', 'njk')
app.use(express.static('static'));
nunjucks.configure('views', {
    autoescape: true,
    express: app
});

// routes
app.get('/', (req, res) => {
    let username = req.oidc.user?.name || undefined;
    res.render('index', { loggedIn: req.oidc.isAuthenticated(), username: username });
})

app.get('/profile', requiresAuth(), (req, res) => {
    res.send(JSON.stringify(req.oidc.user));
});

app.post('/', async (req, res) => {
    const prompt = req.body.prompt
    console.log(prompt);
    const completion = await invokeClaude(prompt);
    //console.log(completion);
    //res.render('index');
    res.json({ 'response': completion });
})

// req.isAuthenticated is provided from the auth router
app.get('/test', (req, res) => {
    res.send(req.oidc.isAuthenticated() ? 'Logged in' : 'Logged out');
});

// custom error handler
app.use((err, req, res, next) => {
    console.error(err.stack)
    res.status(500).send('Something broke!')
})

//The 404 Route (ALWAYS Keep this as the last route)
app.get('*', function (req, res) {
    res.status(404).render('404');
});

const EXPRESS_PORT = process.env.EXPRESS_PORT || 8080;
const EXPRESS_HOST = process.env.EXPRESS_HOST || '0.0.0.0';
app.listen(EXPRESS_PORT, EXPRESS_HOST, () => {
    console.log(`Express app listening at ${EXPRESS_HOST}:${EXPRESS_PORT}`);
});
