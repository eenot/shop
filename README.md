# The Plentiful Shop

## Use cases

- Programmers sells their screencasts, tutorials (e.g. [Pragmatic Studio](https://pragmaticstudio.com/elm))
- Comics sells their shows (e.g. [Louis CK](https://louisck.net/))
- Writers sells their articles, books, blog posts, essays.
- Artists sells their drawings, comicbooks.

Let us start from programmers, because they can deploy everything by themselves.

## What you can do with version 1.0

Publishers add issues and customers buys those issues.
Each issue is just an HTML page.
Optionally: issues and their assets are delivered via [signed URLs](http://docs.aws.amazon.com/AmazonCloudFront/latest/DeveloperGuide/private-content-signed-urls.html).

### As a publisher

- Deploy
  - Clone this repository
  - Deploy this web app on your server
- Setup (via configuration file(s))
  - Connect your Stripe account
  - Connect your AWS account (store assets on S3 and deliver over CloudFront)
  - Connect your Firebase account (user authentication, customers, issues, purchases)
- Upload assets (via AWS console)
- Track purchases and customers (via Firebase and Stripe)
- Add issues (HTML template for each issue via Firebase)
- Backup database (JSON export via Firebase)

### As a customer

- Sign-up, then sign-in, and sign-out.
- Top up your account via Stripe.
- Navigate among issues and preview issues.
- Buy issues (use your credits to unlock issues one by one).

## Development

1. Install node (e.g. on OS X use [Homebrew](http://brew.sh/) `brew install node`).
1. Run `npm install elm -global` once to install [Elm](http://elm-lang.org).
1. Then `npm install && npm start` to install and serve the web app.
1. Open  <http://localhost:3000/>.

[MIT](LICENSE.md).
Copyright [The Plentiful](https://www.plentiful.me).
