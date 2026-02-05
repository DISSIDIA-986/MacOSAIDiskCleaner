# GitHub Secrets Configuration Guide

## Required Secrets for CI/CD

### Optional Secrets (Recommended for Production Release)

#### 1. APPLE_SIGNING_IDENTITY
- **Description**: Apple Developer certificate name for code signing
- **Example**: `Developer ID Application: Your Name (TEAMID)`
- **How to Get**:
  1. Open Xcode → Preferences → Accounts
  2. Select your Apple Developer account
  3. View your certificate in "Manage Certificates"
  4. Copy the certificate name
- **Required**: No (builds will run without signing if empty)
- **Note**: You can use free Apple ID for local testing, but paid Developer Program required for distribution

#### 2. APPLE_TEAM_ID
- **Description**: Apple Development Team ID (10-character alphanumeric)
- **Example**: `ABC123XYZ4`
- **How to Get**:
  1. Go to [Apple Developer Account](https://developer.apple.com/account)
  2. Navigate to "Membership" section
  3. Find your "Team ID"
- **Required**: No (only needed if using code signing)

#### 3. SPARKLE_PRIVATE_KEY
- **Description**: Private key for Sparkle appcast signing
- **Format**: Ed25519 private key (base64 or PEM format)
- **How to Generate**:
  ```bash
  # Generate new key pair
  openssl genpkey -algorithm ED25519 -out sparkle_private.pem
  openssl pkey -in sparkle_private.pem -pubout -out sparkle_public.pem

  # Convert to base64 for GitHub Secret
  base64 -i sparkle_private.pem | tr -d '\n'
  ```
- **How to Get**: Generate using the commands above
- **Required**: No (appcast generation will be skipped if empty)
- **Security**: Keep private key secure, never commit to repo

### Automatic Secrets

#### GITHUB_TOKEN
- **Description**: GitHub-provided token for API access
- **Status**: Automatically available in workflows
- **Usage**: Creating releases, uploading artifacts
- **Action**: No configuration needed

## Configuration Steps

### Step 1: Open Repository Settings
1. Go to your repository on GitHub
2. Click **Settings** tab
3. Navigate to **Secrets and variables** → **Actions**

### Step 2: Add Secrets
For each secret:
1. Click **New repository secret**
2. Name: Use the exact name from the list above (e.g., `APPLE_SIGNING_IDENTITY`)
3. Value: Paste your secret value
4. Click **Add secret**

### Step 3: Verify Secrets
- After adding, secrets should appear in the list
- Secrets are not visible after adding (only shows "Updated" time)
- Secrets are available in all workflows immediately

## Testing Without Secrets

### Development Mode (No Secrets)
The workflows are designed to work without secrets:
- ✅ CI pipeline: Runs completely without secrets
- ✅ Release build: Builds without code signing
- ✅ DMG creation: Creates unsigned DMG
- ⚠️ Appcast: Skipped if `SPARKLE_PRIVATE_KEY` is missing

### With Free Apple ID
If you have a free Apple ID (not paid Developer Program):
- You can build locally with your free Apple ID
- GitHub Actions can build without signing
- Users may need to right-click → Open to run the app
- Works fine for personal projects and testing

### With Paid Developer Program ($99/year)
If you have Apple Developer Program membership:
- You can distribute signed applications
- Apps can be installed without gatekeeper warnings
- You can enable automatic updates via Sparkle
- Apps can be notarized by Apple

## Security Best Practices

### Secret Management
1. **Never commit secrets to repository**
2. **Use different secrets for development and production**
3. **Rotate secrets periodically**
4. **Revoke leaked secrets immediately**
5. **Use minimum required permissions**

### For Apple Certificates
- Store certificates securely in Keychain
- Backup certificates in safe location
- Monitor certificate expiration dates
- Use provisioning profiles for app distribution

### For Sparkle Keys
- Generate unique keys for each app
- Keep private key secure (never in repo)
- Public key can be committed to repo
- Rotate keys if compromised

## Troubleshooting

### Build Fails with "No signing identity"
**Problem**: Code signing fails even though secret is set
**Solution**:
- Verify `APPLE_SIGNING_IDENTITY` matches exactly
- Check that certificate is not expired
- Ensure `APPLE_TEAM_ID` is correct

### Sparkle Appcast Fails
**Problem**: `generate_appcast` fails
**Solution**:
- Verify `SPARKLE_PRIVATE_KEY` is in correct format
- Ensure key is base64 encoded
- Check that private key matches public key in repo

### Workflow Permission Errors
**Problem**: "Resource not accessible by this integration"
**Solution**:
- Go to Settings → Actions → General → Workflow permissions
- Enable "Read and write permissions"

## Summary

### Minimum for CI (Testing)
- **None** - All tests run without secrets

### Recommended for Release
- `APPLE_SIGNING_IDENTITY` - For code signing
- `APPLE_TEAM_ID` - Your Apple Developer Team ID
- `SPARKLE_PRIVATE_KEY` - For appcast signing

### Configuration Checklist
- [ ] Add Apple signing credentials (optional)
- [ ] Add Sparkle private key (optional)
- [ ] Verify workflow permissions
- [ ] Test CI pipeline on a PR
- [ ] Test release with a draft tag

---

**Last Updated**: 2026-02-05
**For Questions**: Open an issue in the repository
