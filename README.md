# TemplateBotRepo

This repository is for the **TemplateBot**. It is a piece of automation that can help add templates to your repositories across the Organization(s).
Its goal is to help ensure your users repositories have basic *files*, *templates*, *automations*, and organizational *best practices* in their repositories.

## How it works

The **TemplateBot** works in the following way:

- **Clone** this repository to your Organization
  - The access rights should be `public`, or `internal`
- Create An Organization level **GitHub App** called **TemplateBot**
  - Full details can be found in the `Create GitHub App` section
- Store the `App Id` and `Private Key` in the *TemplateBot** repository as secrets
  - It will use them as authentication to the Organization, and its repositories
- Set the `cron` schedule to run the **TemplateBot**
  - By default, it runs every `2` hours
- **GitHub Actions** Will now send the **TemplateBot** to query your organizations repositories and look for repositories that have not had a template applied
- Once a repository is found, it will clone the repository to inject a **GitHub Action** and open a Pull Request
- The user can then select the template they would like from the Pull Request
- The **Github Action** will trigger and add the files from the template into the repositories open Pull Request
- It will then comment back to the open Pull Request and ask the user to validate and merge

### Create GitHub App

- [Create a GitHub App](https://docs.github.com/en/developers/apps/building-github-apps/creating-a-github-app)
As you can see from the link above, creating a **GitHub App** is fairly straight forward.
You only need to maker sure you give the **GitHub App** the proper permissions to be able to perform the API calls you may be looking to complete.
**Note:** There is a organization limit of `100` **GitHub Apps**

The **TemplateBot** will need the following access rights:

- **Contents**: `read and write`
- **Issues**: `read and write`
- **Metadeta**: `read`
- **Pull requests**: `read and write`
- **Secrets**: `read`

Once set, you can install the **TemplateBot** to `all repositories` in the organization.

## Create a Personal Access Token from the GitHub App

Once you have created a **GitHub App**, you will have a `*.pem` to use to authenticate as the **GitHub App**, but not a usable **Personal Access Token**.
One of the easiest ways to do so is to use a tool to help generate the token. Some of the preferred ways include:

- [GitHub App Token Generator](https://github.com/navikt/github-app-token-generator)
  - Open-source **GitHub Action** that takes the secrets of `APP_ID` and `PRIVATE_KEY` to generate a usable **Personal Access Token**
- [gh-token](https://github.com/Link-/gh-token)
  - As you can see from the [Installation](https://github.com/Link-/gh-token#installation), using `curl`, `wget`, or the `gh cli extension` to download and install the script
  - Once you have that completed, you can run the tool to generate the token

### Example of GitHub App Token Generator

```yml
- name: Generate PAT with APP
  uses: navikt/github-app-token-generator@v1
  id: get-token
  with:
    private-key: ${{ secrets.PRIVATE_KEY }}
    app-id: ${{ secrets.APP_ID }}

- name: Check out some other repo using created token
  uses: actions/checkout@v2
  with:
    repository: owner/repo
    token: ${{ steps.get-token.outputs.token }}
```

### Example of gh-token

```bash
ghtoken generate \
    --key created-github-app-private-key.pem \
    --app_id 1122334 \
    --duration 1500
    | jq
```

As you cans see from the example above, we run the script and pass the `--key` to point to the key you were able to download from the installed **Github App**.
We also need to know the `app_id` of the installed **GitHub App**. This can be obtained by going to your Organization Url: `https://github.com/organizations/ORG_NAME/settings/installations/`.
From there, select the correct **Github App** and select `Configure`. Notice the URL and you will see the `app_id` needed for the command.
We also set the duration to `1500` minutes (Little over 1 day). The default is `10` minutes if not specified.
Once the command is run, you will be returned the following data:

```bash
{
  "token": "ghs_g7___MlQiHCYI__________7j1IY2thKXF",
  "expires_at": "2021-04-28T15:53:44Z"
}
```

The `token` can now be grabbed and used for the run of your tooling for the lifetime of its existence.

#### Notes

The tool **Link-/gh-token** also has many other capabilities like `revoking tokens`, converting to `base_64`, etc... so please run the command: `gh-token --help` for more information.
