#!/bin/sh

# PASSED INTO HOOK BY SCALR TO BE REMOVED
SCALR_HOSTNAME=eftours.scalr.io
SCALR_RUN_ID=run-v0ntf7fn09tsn2g2d
# PASSED INTO HOOK BY SCALR TO BE REMOVED

GITHUB_API_HOSTNAME=api.github.com
GITHUB_SERVER_HOSTNAME=github.com

post_pr_comment() {
  # Get Scalr run data and set shell vars for plan ID, commit sha and github repo
RUN_RESPONSE=$(curl -X GET --silent --show-error --location \
    --url "https://${SCALR_HOSTNAME}/api/iacp/v3/runs/${SCALR_RUN_ID}?include=vcs-revision" \
    -H "Content-Type: application/vnd.api+json" \
    -H "Authorization: Bearer ${SCALR_TOKEN}" \
    -H "Prefer: profile=preview")
  # | jq --raw-output '@sh "PLAN_ID=(.data.relationships.plan.data.id) 

  COMMIT_SHA=$(jq -r '.included[0].attributes."commit-sha"' << EOF
$RUN_RESPONSE
EOF
)

  GITHUB_REPOSITORY=$(jq -r '.included[0].attributes."repository-id"' << EOF
$RUN_RESPONSE
EOF
  )

  PLAN_ID=$(jq -r '.data.relationships.plan.data.id' << EOF
$RUN_RESPONSE
EOF
  )

  PLAN_STATUS=$(jq -r '.data.attributes.status' << EOF
$RUN_RESPONSE
EOF
  )

  # Get the github PR's issue number for posting an issue comment
  GITHUB_PR_RESPONSE="$(curl -X GET --silent --show-error --location \
    --url "https://${GITHUB_API_HOSTNAME}/repos/${GITHUB_REPOSITORY}/commits/${COMMIT_SHA}/pulls" \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer ${GITHUB_TOKEN}")"

  PULL_REQUEST_ISSUE_NUMBER=$(jq -r '.[].number' << EOF
$GITHUB_PR_RESPONSE
EOF
  )

  GITHUB_ACTOR=$(jq -r '.[].user.login' << EOF
$GITHUB_PR_RESPONSE
EOF
  )

  # Get the Scalr run output
  PLAN_OUTPUT="$(curl -X GET --silent --show-error --location \
    --url "https://${SCALR_HOSTNAME}/api/iacp/v3/plans/${PLAN_ID}/output" \
    -H "Content-Type: application/vnd.api+json" \
    -H "Authorization: Bearer ${SCALR_TOKEN}" \
    -H "Prefer: profile=preview")"

  # Scalr plan output doesn't give an option to not include colorization characters and we don't want to disable it via TF var in Scalr
  # So we'll regex it away to oblivion using sed prior to passing to grep
  PLAN_SUMMARY=$(echo "${PLAN_OUTPUT}" | sed -r "s/\x1B\[([0-9]{1,2}(;[0-9]{1,2})?)?[m|K]//g" | grep -E '^No changes.|^Plan:|^Error|^Changes to Outputs:')

  ###
  # Post issue comment
  ###
  plan_max_length=64000

  plan_title="Full Plan Output"
  plan_truncated_message=""

  echo "Plan length: ${#PLAN_OUTPUT}"
  if [ ${#PLAN_OUTPUT} -gt ${plan_max_length} ] ; then
    plan_title="Truncated Plan Output"
    plan_truncated_message="Plan output is too long and was truncated. You can read full Plan in the <a href=\"https://${GITHUB_SERVER_HOSTNAME}/${GITHUB_REPOSITORY}/actions/runs/${GITHUB_RUN_ID}\">Actions run</a>.<br /><br />"
    PLAN_OUTPUT=$(printf '%s' "${PLAN_OUTPUT}" | head -c $plan_max_length)
  fi

# #### Terraform Initialization ⚙️\`${{ steps.init.outcome }}\`
# #### Terraform Format and Style 🖌\`${{ steps.fmt.outcome }}\`
# <details><summary>Format Output</summary>

# \`\`\`\n
# ${{ steps.fmt.outputs.stdout }}
# \`\`\`

# </details>

# #### Terraform Validation 🤖\`${{ steps.validate.outcome }}\`
# <details><summary>Validation Output</summary>

# \`\`\`\n
# ${{ steps.validate.outputs.stdout }}
# \`\`\`

# </details>
# }} \`


  output=$(cat <<EOF
#### Terraform Plan 📖\`${PLAN_STATUS}\`

Plan Summary: \` ${PLAN_SUMMARY} \`

<details><summary>${plan_title}</summary>

\`\`\`\n
${PLAN_OUTPUT}
\`\`\`
</details>
${plan_truncated_message}

*Pusher: @${GITHUB_ACTOR}*
EOF
)

# echo "${output}"

ENCODED_OUTPUT=$( jq -n --arg string "$output" '$string' )
# echo "${ENCODED_OUTPUT}"

  curl -X POST --show-error --location \
    --url "https://${GITHUB_API_HOSTNAME}/repos/${GITHUB_REPOSITORY}/issues/${PULL_REQUEST_ISSUE_NUMBER}/comments" \
    -H "Content-Type: application/vnd.github+json" \
    -H "Authorization: Bearer ${GITHUB_TOKEN}" \
    -H "X-GitHub-Api-Version: 2022-11-28" \
    --data-raw '{ "body": '"${ENCODED_OUTPUT}"' }'

}

# if [ "${SCALR_TERRAFORM_OPERATION}" = "apply" ] && [ "${DOWNSTREAM_WORKSPACE_ID}" != "" ]; then
#   if [ "${SCALR_TERRAFORM_EXIT_CODE}" = "0" ]; then
#     echo "Terraform Apply was successful. Triggering downstream Run in ${DOWNSTREAM_WORKSPACE_ID}..."
    post_pr_comment
#   else
#     echo "Terraform Apply failed."
#   fi
# fi
