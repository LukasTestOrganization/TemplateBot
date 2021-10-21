#!/bin/bash
################################################################################
################################################################################
####### Apply TemplateBot Template to repository @AdmiralAwkbar ################
################################################################################
################################################################################

# LEGEND:
# This script will find the template that should be applied to the repository
# and add the files in the current branch, and push the code to the repository
# It will also clean up the template bot workflow to clean up the code base
#
# PREREQS:
# You need to have the following to run this script successfully:
# - GitHub Personal Access Token with access to the Organization
# - jq installed on the machine running the query
#

###########
# GLOBALS #
###########
GITHUB_API='https://api.github.com' # API URL
DEBUG="${DEBUG:-false}" # Set to 'true' to enable debugging
TEMPLATE=''             # Pulled form the body | template1, template2, etc...
##############
# Input vars #
##############
BODY=$1 # JSON Object passed from GitHub
REF=$2  # Name of the branch to push
REPO=$3 # Org/Repo
PR=$4   # Pull Request ID
####################
# TemplateBot Vars #
####################
TEMPLATEBOT_WORKFLOW='template-bot-issue-ops.yml' # Name of the issue ops Action
TEMPLATEBOT_DIR='templatebotrepo'                 # Name of the repo Folder cloned in

################################################################################
############################ FUNCTIONS #########################################
################################################################################
################################################################################
#### Function Header ###########################################################
Header() {
  echo ""
  echo "######################################################"
  echo "######################################################"
  echo "############# TemplateBot Apply Template #############"
  echo "######################################################"
  echo "######################################################"
  echo ""
  debug "BODY:[${BODY}]"
  debug "REF:[${REF}]"
  debug "REPO:[${REPO}]"
  debug "PR:[${PR}]"

}
################################################################################
#### Function DebugJQ ##########################################################
DebugJQ() {
  # If Debug is on, print it out...
  if [[ ${DEBUG} == true ]]; then
    echo "$1" | jq '.'
  fi
}
################################################################################
#### Function Debug ############################################################
Debug() {
  # If Debug is on, print it out...
  if [[ ${DEBUG} == true ]]; then
    echo "$1"
  fi
}
################################################################################
#### Function Footer ###########################################################
GetTemplate() {
  echo "-----------------------------------------------"
  echo "Getting Template name from PR..."

  # Need to pull the template info from the updated body
  TEMPLATE=$(echo "${BODY}" |grep -m1 "\[x\]" |awk '{print $3}')
  debug "TEMPLATE:[${TEMPLATE}]"

  #########################
  # Check we have a value #
  #########################
  if [ -z "${TEMPLATE}" ]; then
    echo "ERROR! Failed to get the template from the BODY!"
    exit 1
  fi

  echo "Template is set to:[${TEMPLATE}]"
}
################################################################################
#### Function CopyFiles ########################################################
CopyFiles() {
  # Need to copy the files from the template folder into thier desired locations
  echo "-----------------------------------------------"
  echo "Copy of templates from TemplateBot into repository..."

  ##############################
  # Rsync the files into place #
  ##############################
  RSYNC_CMD=$(rsync -va "${TEMPLATEBOT_DIR}/templates/${TEMPLATE}/" . 2>&1)
  debug "RSYNC_CMD:[${RSYNC_CMD}]"

  #######################
  # Load the error code #
  #######################
  ERROR_CODE=$?

  ##############################
  # Check the shell for errors #
  ##############################
  if [ ${ERROR_CODE} -ne 0 ]; then
    # Error
    echo "ERROR! FAiled to rsync files into place!"
    echo "ERROR:[${RSYNC_CMD}]"
    exit 1
  else
    echo "Successfully copied template files to repository"
  fi

}
################################################################################
#### Function Cleanup ##########################################################
Cleanup() {
  # Need to remove the TemplateBot repo that was cloned in,
  # and the old dead workflow

  echo "-----------------------------------------------"
  echo "Cleanup of the TemplateBot..."

  ##############################
  # Remove the TemplateBot dir #
  ##############################
  REMOVE_TEMPLATEBOT_CMD=$(rm -rf "${TEMPLATEBOT_DIR}" 2>&1)
  debug "REMOVE_TEMPLATEBOT_CMD:[${REMOVE_TEMPLATEBOT_CMD}]"

  ############################
  # Check if the file exists #
  ############################
  if [ -d "${TEMPLATEBOT_DIR}" ]; then
    echo "ERROR! FOlder still exists at:[${TEMPLATEBOT_DIR}]"
    echo "ERROR:[${REMOVE_TEMPLATEBOT_CMD}]"
    exit 1
  else
    echo "Successfully removed TemplateBot cloned folder"
  fi

  ############################
  # Remove the Workflow file #
  ############################
  REMOVE_WORKFLOW_CMD=$(rm -f ".github/workflows/${TEMPLATEBOT_WORKFLOW}" 2>&1)
  debug "REMOVE_WORKFLOW_CMD:[${REMOVE_WORKFLOW_CMD}]"

  ############################
  # Check if the file exists #
  ############################
  if [ -f ".github/workflows/${TEMPLATEBOT_WORKFLOW}" ]; then
    echo "ERROR! File still exists at:[.github/workflows/${TEMPLATEBOT_WORKFLOW}]"
    exit 1
  else
    echo "Successfully removed TemplateBot issue Ops workflow file"
  fi
}
################################################################################
#### Function PushToGitHub #####################################################
PushToGitHub() {
  # Need to commit the files, and push up to the open PR

  ##################
  # Set the Config #
  ##################
  echo "-----------------------------------------------"
  echo "Setting git config of the TemplateBot..."
  CONFIG_CMD=$(git config --global user.email "template@bot.com"; git config --global user.name "TemplateBot" 2>&1)
  debug "CONFIG_CMD:[${CONFIG_CMD}]"

  #######################
  # Load the error code #
  #######################
  ERROR_CODE=$?

  ##############################
  # Check the shell for errors #
  ##############################
  if [ ${ERROR_CODE} -ne 0 ]; then
    echo "ERROR! Failed to set git config!"
    echo "ERROR:[${CONFIG_CMD}]"
    exit 1
  fi

  #############
  # Add files #
  #############
  echo "-----------------------------------------------"
  echo "Adding template files to commit..."
  ADD_CMD=$(git add . 2>&1)
  debug "ADD_CMD:[${ADD_CMD}]"

  #######################
  # Load the error code #
  #######################
  ERROR_CODE=$?

  ##############################
  # Check the shell for errors #
  ##############################
  if [ ${ERROR_CODE} -ne 0 ]; then
    echo "ERROR! Failed to add files to git commit!"
    echo "ERROR:[${ADD_CMD}]"
    exit 1
  fi

  ###################
  # Commit and push #
  ###################
  echo "-----------------------------------------------"
  echo "Pushing files to GitHub..."
  PUSH_CMD=$(git commit -m "Adding template files from TemplateBot"; git push origin "HEAD:${REF}" 2>&1)
  debug "PUSH_CMD:[${PUSH_CMD}]"

  #######################
  # Load the error code #
  #######################
  ERROR_CODE=$?

  ##############################
  # Check the shell for errors #
  ##############################
  if [ ${ERROR_CODE} -ne 0 ]; then
    echo "ERROR! Failed to push file to GitHub!"
    echo "ERROR:[${PUSH_CMD}]"
    exit 1
  fi
}
################################################################################
#### Function PRComment ########################################################
PRComment() {
  # Need to leave a comment about automation may not
  # work due to action calling action
  ##################
  # Create comment #
  ##################
  echo "-----------------------------------------------"
  echo "Pushing PR comment to GitHub..."
  CREATE_CMD=$(curl -s --fail -X POST \
    --url "${GITHUB_API}/repos/${REPO}/issues/${PR}/comments" \
    -H "Authorization: Bearer ${GITHUB_TOKEN}" \
    -H 'Content-Type: application/json' \
    -d '{	"body": "TemplateBot has successfully pushed a commit to this PR.\nDue to a *limitation* with **GitHub Actions** not being able to Call other **GitHub Actions**, the last push may not trigger any defined **GitHub Actions** you may have active.\nPlease review the changes and merge accordingly.\n\nThank You,\nTemplateBot" }' 2>&1)

  debug "CREATE_CMD:[${CREATE_CMD}]"

  #######################
  # Load the error code #
  #######################
  ERROR_CODE=$?

  ##############################
  # Check the shell for errors #
  ##############################
  if [ ${ERROR_CODE} -ne 0 ]; then
    echo "ERROR! Failed to update comments for PR:[${PR}]!"
    echo "ERROR:[${CREATE_CMD}]"
    exit 1
  fi
}
################################################################################
#### Function Footer ###########################################################
Footer() {
  #######################################
  # Basic footer information and totals #
  #######################################
  echo ""
  echo "######################################################"
  echo "The script has completed"
  echo "######################################################"
  echo ""
  echo ""
}
################################################################################
############################## MAIN ############################################
################################################################################

##########
# Header #
##########
Header

#######################################
# Get the template that is being used #
#######################################
GetTemplate

#####################################
# Copy files and folders into place #
#####################################
CopyFiles

###########
# Cleanup #
###########
Cleanup

###########################################
# Push the files back to the pull request #
###########################################
PushToGitHub

#####################
# Create PR comment #
#####################
PRComment

##########
# Footer #
##########
Footer
