# Strongbox Password Safe
A Personal Password Manager for iOS that can be found on the Apple App Store here: 

https://itunes.apple.com/us/app/strongbox-password-safe/id897283731

and you can find the home page for the app here:

https://strongboxsafe.com

Strongbox supports the open source Password Safe (version 3) and KeePass file formats (KeePass 1 and 2, i.e. KDB, KDBX (3.1 and 4)). Strongbox uses open source encryption algoritms likes TwoFish, Argon2d, ChaCha20, Aes, Salsa20 and various other cryptographic techniques (SHA256s, HMACs, CSPRNGs) to store groups and entries, containing various secrets, mostly designed around password storage. You can also store File Attachments in KeePass format safes.

# Build Issues
The code is provided here for reasons of security, transparency and openness. Anyone can view the code and verify that everything is above board, the algorithms are correct and there are no backdoors or other malicious features present. You will need Google Drive, OneDrive and Dropbox developer accounts (with keys/secrets) before building. Familiarity with Cocoapods and other build tools is a prerequisite. Please do not file issues about build issues, I can't guarantee what is here will build in your environment. If instead of examining the code, you simply want to use the app, please download from the App Store. Lastly, if you are attempting to bypass built-in Pro/Free limitations for your own app usage, please consider your actions, and consider supporting further development by contributing via the official application (in app purchase upgrade). It will be very much appreciated. 

# Acknowledgements
The Crypto is mostly from TomCrypt and libsodium. PasswordSafe & KeePass DB parsing/navigation/UI/Cloud interaction is my own work. 

The official PasswordSafe github repository is here:

https://github.com/pwsafe

The official KeePass github repository is here:

https://github.com/dlech/KeePass2.x

I use many different libraries in the app here are just a few:

- Dropbox-iOS-SDK
- Google-API-Client
- JNKeychain
- SVProgressHUD
- Reachability
- ISMessages
- libsodium
- PopupDialog
- DZNEmptyDataSet
- XWSI

