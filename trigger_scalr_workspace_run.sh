#/bin/sh

DOWNSTREAM_WORKSPACE_ID=${1}

# See: https://docs.scalr.com/en/latest/api/preview/runs.html#create-a-run
# --slient           - Use silent mode / don't display progress
# --show-error       - Show error even when silent mode is used
# --output /dev/null - Redirect "info" to null / Don't display response info
# --location         - follow redirects
trigger_run() {
  curl -X POST --silent --show-error --output /dev/null --location \
    --url "https://${SCALR_HOSTNAME}/api/iacp/v3/runs" \
    -H "Content-Type: application/vnd.api+json" \
    -H "Authorization: Bearer ${SCALR_TOKEN}" \
    -H "Prefer: profile=preview" \
    --data-binary @- << EOF
{
  "data": {
    "type": "runs",
    "attributes": {
      "message": "Triggered by ${SCALR_RUN_ID}"
    },
    "relationships": {
      "workspace": {
        "data": {
          "id": "${DOWNSTREAM_WORKSPACE_ID}",
          "type": "workspaces"
        }
      }
    }
  }
}
EOF
}

# if [ "${SCALR_TERRAFORM_OPERATION}" = "apply" ] && [ "${DOWNSTREAM_WORKSPACE_ID}" != "" ]; then
if [ "${DOWNSTREAM_WORKSPACE_ID}" != "" ]; then
  if [ "${SCALR_TERRAFORM_EXIT_CODE}" = "0" ]; then
    echo "Terraform Apply was successful. Triggering downstream Run in ${DOWNSTREAM_WORKSPACE_ID}..."
    trigger_run
  else
    echo "Terraform Apply failed."
  fi
fi
