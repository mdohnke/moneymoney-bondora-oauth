# moneymoney-bondora-oauth
MoneyMoney Extension for Bondora using the API and OAuth2.
The extension will provide the balance of your Go&Grow accounts.

The implementation is inspired by:
* https://github.com/diederich/moneymoney-monzo for handling OAuth2 in MoneyMoney
* https://github.com/EmDee/moneymoney-bondora for Bondora API features

## Installation
* Download the extension from this repository
* In MoneyMoney go to Help > Show database in finder (German: Hilfe > Datenbank im Finder zeigen)
* Add the downloaded Bondora.lua file to the directory "Extensions"
* Deactivate the signature check
![moneymoney signature check](assets/moneymoney-deactivate-signature-check.png)

**Later**
* Download the extension from the official [extensions page](https://moneymoney-app.com/extensions/)
* In MoneyMoney go to Help > Show database in finder (German: Hilfe > Datenbank im Finder zeigen)
* Add the downloaded Bondora.lua file to the directory "Extensions"

## Usage

### Preparation: Create application in your Bondora API settings
Create an application with the following values by navigating to api.bondora.com > Applications > Create New 
* Application name must be unique. Choose something like "MoneyMoney - YourName" or whatever you want. This value is never used in the extension. You get an error message if any other user already used your chosen value.
* Homepage URL: https://service.moneymoney-app.com/1/redirect
* Application description: Choose some text to describe the access, i.e. "Access for MoneyMoney finance app"
* Authorization callback URL: https://service.moneymoney-app.com/1/redirect 
![bondora create application](assets/bondora-create-application.png)

### Create Account in MoneyMoney
* Add a new account and select 'Bondora Account (OAuth2)" in the 'Others' category.
* Enter the following values from your API application settings: 
    * Client ID as username 
    * Client Secret as password
![bondora application created](assets/bondora-application-settings.png)

**TODO:**
* Handle http 429 error due to API rate limiting
* Get caching to work (API rate limiting)

## Limitation
TODO: remove this limitation

This extension will only work, if your English preferences for decimal and thousand separator are following the default setting:
![bondora decimal and thousand separator preferences](assets/bondora-preferences.png)


## To clarify with MM Development
* Is using LocalStorage with big data a problem (for the performance of MoneyMoney for example)?
* Is the LocalStorage divided in spaces or are the variables available for all extenstions? 
* Big http responses slow down the log file view. Is it possible to deactivate logging for specific http calls?