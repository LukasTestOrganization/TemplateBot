# TemplateBot Automation

This folder contains the automations needed to run the **TemplateBot** on a users repository.
Below is information on the various components.

---
## template-the-world.sh

This is the main brains of the **TemplateBot**. This script uses GitHub Graphql API to find all repositories in the organization, and query if they have had a template applied to them.
If no template or blocking topic is found, then the script clones the users repository, adds the **GitHub Action** `template-bot-issue-ops.yml` and creates an Open Pull Request.
This will then let the users decide what template they would like to have applied to their repository.
---

## template-bot-issue-ops.yml

This is the injected **Github Action** that is applied to the users codebase when their repository has been selected to have a template applied to it.
Once this **GitHub Action** has been added to a users repository, it will generate a Pull Request to set this action up to be ran.
This script in turn calls the `apply-template.sh` on the users repository to apply the template selected.

---

## apply-template.sh

This is the script that is called when a user makes a selection to the template in the generated Pull Request.
This script is passed the following information:

- **BODY**
  - This is the `body` text of the Pull Request body. It is used to see what template was selected by the user
- **REF**
  - This is the name of the `branch` created to run the Pull Request. Its used to push templates back to **GitHub**
- **REPO**
  - This is the `Org/Repo` name and used to call the API's to generate a comment
- **PR**
  - This is the Pull Request `number` that we use to point the comment back into the open Pull Request

The script is called from the **GitHub Action** `template-bot-issue-ops.yml` that is triggered when a user makes a selection on the template to be applied.
From that point, the script gathers the information, applies the template, pushes the code back to GitHub, and updates the Pull Request with a comment to merge the changes.

---
