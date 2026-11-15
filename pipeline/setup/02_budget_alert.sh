#!/bin/bash
# =============================================================================
# 02_budget_alert.sh - e-mail me when spending reaches 50%, 90% and 100% of $50.
#
# A budget does NOT stop spending; it only warns you. That is enough here,
# because the whole project should cost well under $50 of your $300 credit.
# =============================================================================
set -e
# shellcheck source=../config.sh
source "$(dirname "$0")/../config.sh"

echo "==> Finding the billing account linked to $PROJECT_ID..."
# The answer looks like "billingAccounts/01ABCD-234EFG-56789H"; sed keeps the ID.
BILLING_ACCOUNT=$(gcloud billing projects describe "$PROJECT_ID" \
    --format="value(billingAccountName)" | sed 's|billingAccounts/||')
echo "    Billing account: $BILLING_ACCOUNT"

# A budget must use the billing account's own currency. This script sets
# $50, so it only runs for USD accounts; other currencies use the console.
CURRENCY=$(gcloud billing accounts describe "$BILLING_ACCOUNT" --format="value(currencyCode)")
if [ "$CURRENCY" != "USD" ]; then
    echo "Your billing account uses $CURRENCY, not USD."
    echo "Create the budget in the console instead: Billing > Budgets & alerts >"
    echo "Create budget, with about the value of 50 USD and alerts at 50/90/100%."
    exit 0
fi

# --billing-project tells gcloud which project "pays" for this API call.
EXISTING=$(gcloud billing budgets list --billing-account="$BILLING_ACCOUNT" \
    --billing-project="$PROJECT_ID" \
    --filter="displayName=dataco-budget" --format="value(name)")

if [ -z "$EXISTING" ]; then
    echo "==> Creating the budget 'dataco-budget' (\$50, alerts at 50/90/100%)..."
    gcloud billing budgets create \
        --billing-account="$BILLING_ACCOUNT" \
        --billing-project="$PROJECT_ID" \
        --display-name="dataco-budget" \
        --budget-amount=50USD \
        --filter-projects="projects/$PROJECT_ID" \
        --threshold-rule=percent=0.5 \
        --threshold-rule=percent=0.9 \
        --threshold-rule=percent=1.0
else
    echo "==> Budget 'dataco-budget' already exists - nothing to do."
fi
