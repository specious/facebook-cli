## Facebook configuration

To interact with the Facebook API you must create and configure a new Facebook application for your personal use.

- Go to https://developers.facebook.com/apps and click "Add a New App"
  ![Create a new Facebook application](images/initial-configuration/create-new-app.png)
- Go to the "Settings" tab
  - Click "Add Platform"
  - Select "Website"
    ![Select platform](images/initial-configuration/select-platform.png)
  - Set "Site URL" to `http://localhost`
    ![Set 'Site URL' to 'localhost'](images/initial-configuration/set-site-url-to-localhost.png)
  - Add `localhost` to the "App Domains"
    ![Add 'localhost' to 'App Domains'](images/initial-configuration/add-localhost-to-app-domains.png)
  - Click "Save Changes"
    ![Changes saved](images/initial-configuration/changes-saved.png)
- Go to the "App Review" tab
  - Flip the switch that says "Your app is in **development** and unavailable to the public."
    ![Switch to toggle application live status](images/initial-configuration/make-public-switch.png)
  - Click "Confirm" to make your app live ([why?](# "This is required for any content you publish through this app to be visible to other users."))
    ![Make your application public](images/initial-configuration/make-app-public.png)
- Go to the "Dashboard" tab
  - Under "App Secret" click "Show" to reveal your app secret
    ![Show App Secret](images/initial-configuration/show-app-secret.png)
    ![App Secret revealed](images/initial-configuration/app-secret-revealed.png)
  - Open a terminal and save your App ID and App Secret by running:<br>

    ```
    facebook-cli config --appid=<app-id> --appsecret=<app-secret>
    ```
    ![Save App ID and App Secret](images/initial-configuration/save-app-id-and-app-secret.png)

## Logging in

Once configured, you must log into Facebook with your credentials to authorize *facebook-cli* to interact with your profile.

- Open a terminal
  - Run `facebook-cli login`
    ![Run 'facebook-cli login'](images/login-procedure/facebook-cli-login.png)
  - Open the URL in a web browser, and log into your Facebook account if prompted
  - Click "Continue" to approve the permissions
    ![Approve permissions](images/login-procedure/approve-permissions.png)
  - Select the scope of your audience for any posts you publish using this application ([read more](https://www.facebook.com/help/211513702214269))
    ![Set visibility for your posts](images/login-procedure/set-visibility.png)
  - Click "Ok" to continue
  - Close the browser tab
    ![Log in successful](images/login-procedure/facebook-cli-logged-in.png)