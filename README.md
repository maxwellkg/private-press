# Canon

Canon is a fork of [Writebook](https://github.com/basecamp/writebook).

Writebook is an easy-to-use application for publishing content on the web.
Content is authored in Markdown, and books can contain picture pages, chapters, and title pages.
Books can be published privately or publicly, and are searchable.

Canon has been updated to use the Rails solid trifecta:

- Solid Queue
- Solid Cache
- Solid Cable

Writebook was originally developed to be distributed as a Docker image. Canon has been updated to deploy using Kamal.

To deploy Canon, copy `config/deploy.yml.example` to `config/deploy.yml` and update it with your deployment details.

In production, Canon uses local storage.


## Running in development

Install dependencies:

```sh
bin/setup
```

Start the development server:

```sh
bin/dev
```
