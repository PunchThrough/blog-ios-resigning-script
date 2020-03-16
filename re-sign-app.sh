#!/bin/sh 
# Arguments:
#   IPA file,
#   New app identifier,
#   Name of certificate to sign with.

if [ "$#" -ne 3 ]; then
    echo "Illegal number of parameters. Please pass the IPA file, New app identifier, and name of certificate to sign with as arguments"
    exit 1
fi

IPA_PATH="$1"

# Extract the ipa file
/usr/bin/unzip -o $IPA_PATH
APP_NAME=$(ls ./Payload/)

# Remove the old code signature
rm -r ./Payload/$APP_NAME/_CodeSignature

/usr/libexec/PlistBuddy -c "Set CFBundleIdentifier $2" ./Payload/$APP_NAME/Info.plist
##########################################################
# Here is where you can alter the contents of the Payload directory.

# For example, metadata in the info.plist can be modified:
# /usr/libexec/PlistBuddy -c "Set <Info_Plist_Key> <New_Name>" ./Payload/$APP_NAME/Info.plist
# see PlistBuddy docs for other ways to alter the info plist.

# Embedded content can be replaced as long as the new files match what the application code is looking for.

##########################################################
PROFILE_DIR=~/Library/MobileDevice/Provisioning\ Profiles/

#Create a temporary entitlements file to use when Re-signing the app
echo \
"<?xml version=\"1.0\" encoding=\"UTF-8\"?> \n\
<!DOCTYPE plist PUBLIC \"-//Apple//DTD PLIST 1.0//EN\" \"http://www.apple.com/DTDs/PropertyList-1.0.dtd\"> \n\
<plist version=\"1.0\"> \n\
<dict> \n\
    <key>application-identifier</key> \n\
    <string>$2</string> \n\
    <key>get-task-allow</key> \n\
    <false/> \n\
    <key>keychain-access-groups</key> \n\
    <array> \n\
        <string>$2</string> \n\
    </array> \n\
</dict> \n\
</plist>" \
> ./temp_entitlements.plist

# Find the distribution profile for the new app identifier
pushd ~/Library/MobileDevice/Provisioning\ Profiles/
PROFILE_COUNT=0
for PROFILE in *.mobileprovision; do
    security cms -D -i "$PROFILE" -o temp.plist
    IDENTIFIER=$(/usr/libexec/PlistBuddy -c "Print Entitlements:application-identifier ${APPSTORE_BUNDLE_ID}" temp.plist)
    TYPE=$(/usr/libexec/PlistBuddy -c "Print Entitlements:aps-environment ${APPSTORE_BUNDLE_ID}" temp.plist)
    if [[ "$2" == "$IDENTIFIER" ]] && [[ "production" == "$TYPE" ]]; then
        echo "match: $PROFILE"
        echo "match: $TYPE"
        PROFILE_NAME=$PROFILE
        let "PROFILE_COUNT++"
    fi
done
rm temp.plist
# Ensure that only one profile was found matching the parameters
if [ "$PROFILE_COUNT" -gt 1 ] ; then
    echo "Too many profiles matching identifier \"$2\". Got $PROFILE_COUNT, expected 1"
    exit 1
fi
if [ "$PROFILE_COUNT" -lt 1 ] ; then
    echo "No profiles matching identifier \"$2\"."
    exit 1
fi
popd


# Update the embedded provisioning and code sign the app
/bin/cp -f ~/Library/MobileDevice/Provisioning\ Profiles/$PROFILE_NAME "Payload/$APP_NAME/embedded.mobileprovision"
/usr/bin/codesign -f -s "$3" --entitlements ./temp_entitlements.plist "./Payload/$APP_NAME"

# Re-package the Payload folder into an IPA file
//usr/bin/zip -r "$2.ipa" Payload
popd

# Clean up
rm ./Payload
rm ./temp_entitlements.plist
