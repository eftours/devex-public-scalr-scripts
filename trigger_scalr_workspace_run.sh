#/bin/sh

DOWNSTREAM_WORKSPACE_ID=${1}

# See: https://docs.scalr.com/en/latest/api/preview/runs.html#create-a-run
trigger_run() {
  curl -X POST --silent --location \
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

if [ "${SCALR_TERRAFORM_OPERATION}" = "apply" ] && [ "${DOWNSTREAM_WORKSPACE_ID}" != "" ]; then
  if [ "${SCALR_TERRAFORM_EXIT_CODE}" = "0" ]; then
    echo "Terraform Apply was successful. Triggering downstream Run in ${DOWNSTREAM_WORKSPACE_ID}..."
    trigger_run
  else
    echo "Terraform Apply failed."
  fi
fi
