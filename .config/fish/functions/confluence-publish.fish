function confluence-publish --description "Publish XML file to Confluence page via REST API"
    # Usage: confluence-publish <page_id> <xml_file>
    # Example: confluence-publish 2327478282 ~/docs/my-page.xml

    # Validate arguments
    if test (count $argv) -lt 2
        echo "Usage: confluence-publish <page_id> <xml_file>"
        echo ""
        echo "Arguments:"
        echo "  page_id   - Confluence page ID (from URL)"
        echo "  xml_file  - Path to Confluence Storage Format XML file"
        echo ""
        echo "Environment variables required:"
        echo "  PETLAB_EMAIL  - Your Atlassian email"
        echo "  JIRA_TOKEN    - Your Atlassian API token"
        echo ""
        echo "Example:"
        echo "  confluence-publish 2327478282 ~/obsidian/PLB/my-doc.xml"
        return 1
    end

    set -l PAGE_ID $argv[1]
    set -l XML_FILE $argv[2]

    # Validate environment
    if test -z "$PETLAB_EMAIL" -o -z "$JIRA_TOKEN"
        echo "Error: PETLAB_EMAIL and JIRA_TOKEN must be set"
        echo "Export them in your shell or add to your environment"
        return 1
    end

    # Validate file exists
    if not test -f "$XML_FILE"
        echo "Error: File not found: $XML_FILE"
        return 1
    end

    # Get current page info
    echo "Fetching current page info..."
    set -l PAGE_INFO (curl -s -u "$PETLAB_EMAIL:$JIRA_TOKEN" \
        "https://petlab.atlassian.net/wiki/rest/api/content/$PAGE_ID")

    set -l VERSION (echo $PAGE_INFO | jq -r '.version.number')
    set -l TITLE (echo $PAGE_INFO | jq -r '.title')

    if test "$VERSION" = "null" -o -z "$VERSION"
        echo "Error: Could not fetch page. Check PAGE_ID and credentials."
        echo $PAGE_INFO | jq .
        return 1
    end

    set -l NEW_VERSION (math $VERSION + 1)
    echo "Current version: $VERSION → $NEW_VERSION"
    echo "Page title: $TITLE"

    # Read and escape XML content
    set -l CONTENT (cat $XML_FILE | jq -Rs .)

    # Build payload
    set -l PAYLOAD "{\"version\":{\"number\":$NEW_VERSION},\"title\":\"$TITLE\",\"type\":\"page\",\"body\":{\"storage\":{\"value\":$CONTENT,\"representation\":\"storage\"}}}"

    # Update page
    echo "Publishing to Confluence..."
    set -l RESPONSE (curl -s -u "$PETLAB_EMAIL:$JIRA_TOKEN" \
        -X PUT \
        -H "Content-Type: application/json" \
        "https://petlab.atlassian.net/wiki/rest/api/content/$PAGE_ID" \
        -d "$PAYLOAD")

    # Check result
    if echo $RESPONSE | jq -e '.id' >/dev/null 2>&1
        echo "✓ Successfully published!"
        echo "  Version: $NEW_VERSION"
        echo "  URL: https://petlab.atlassian.net/wiki/spaces/x/pages/$PAGE_ID"
    else
        echo "✗ Publish failed:"
        echo $RESPONSE | jq .
        return 1
    end
end
