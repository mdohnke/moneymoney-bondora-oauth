# moneymoney-bondora-oauth
MoneyMoney Extension for Bondora using the API and OAuth2

This extension is inspired by 
* https://github.com/diederich/moneymoney-monzo for handling OAuth2 in MoneyMoney
* https://github.com/EmDee/moneymoney-bondora for Bondora API features

## Installation
* Download the extension from the official extensions page
* In MoneyMoney go to Help > Show database in finder (German: Hilfe > Datenbank im Finder zeigen)
* Add the downloaded .lua file to the directory "Extensions"


## Usage

### Preparation: Create application in your Bondora API settings
Create an application with the following values by navigating to api.bondora.com > Applications > Create New 
* Application name must be unique. Choose something like "MoneyMoney - <YourName>" or whatever you want (this value is never used in the extension). You get an error message if any other user already used your chosen value.
* Homepage URL: https://service.moneymoney-app.com/1/redirect
* Application description: Choose some text to describe the access, i.e. "Access for MoneyMoney finance app"
* Authorization callback URL: https://service.moneymoney-app.com/1/redirect 

### Create Account in MoneyMoney
* Add a new account and select 'Bondora Account (OAuth2)" in the 'Others' category.
* Enter the following values from your API application settings: 
    * Client ID as username 
    * Client Secret as password

The extension will show your account balance (Go&Grow, other Bondora products)
TODO:
* Add OAuth2 Authentication, especially handling the refresh token
* Add support for Go&Grow
* Add support for other Bondora products
* Handle http 429 error due to API rate limiting

## Limitation
TODO: remove this limitation

This extension will only work, if your English preferences for decimal and thousand separator are following the default setting:
![bondora decimal and thousand separator preferences](assets/bondora-preferences.png)