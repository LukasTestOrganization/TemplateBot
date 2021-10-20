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
GRAPHQL_URL="$GITHUB_API/graphql"   # URL endpoint to graphql
PAGE_SIZE=100      # Default is 100, GitHub limit is 100
END_CURSOR='null'  # Set to null, will be updated after call
DEBUG=''           # Set to 'true' to enable debugging

################################################################################
############################ FUNCTIONS #########################################
################################################################################
################################################################################
#### Function Header ###########################################################
Header()
{
  echo ""
  echo "######################################################"
  echo "######################################################"
  echo "############# TemplateBot Apply Template #############"
  echo "######################################################"
  echo "######################################################"
  echo ""
}
################################################################################
#### Function Footer ###########################################################
Footer()
{
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

##########
# Footer #
##########
Footer
