Welcome to Lenco's API doc

# Welcome to Lenco's API doc

With Lenco API, you can access all your accounts and sub-accounts and their transaction histories. You’ll learn how to build amazing web and mobile integration payment experiences with the Lenco API.

These docs will cover the available endpoints and provide example code for using the API. They will hopefully help you build your own admin tools or automate processes that previously had to be performed manually.

If you have any questions, just send us an email at <support@lenco.co>.

Getting Started

# Getting Started

This page will help you get started with Lenco API

To get your API token (also referred to as api key or secret key), kindly reach out to <support@lenco.co>

## Securing Your API Token

Someone who steals your Lenco API token can interact with your accounts on your behalf, so treat it as securely as you would treat any password. Tokens should never be stored in source control. If you accidentally publicize a token via version control or other methods, you should immediately reach out to <support@lenco.co> to generate a new API token.

## Using the Token

Authenticate your API calls by including your api token in the Authorization header of every request you make.\
Authorization headers should be in the following format: Authorization: `Bearer API_TOKEN`

```
curl -H "Authorization: Bearer xo+CAiijrIy9XvZCYyhjrv0fpSAL6CfU8CgA+up1NXqK"
```

API requests made without authentication will fail with the status code `401: Unauthorized`. All API requests must be made over HTTPS.

## Requests and Response

Both request body data and response data are formatted as JSON. Content type for responses will always be `application/json`. Generally, all responses will be in the following format:

Response Format

```json
{
  "status": [boolean],  // Only true if the details provided could be processed and no error occured while processing
  "message": [string], // Explains why status is false... Entirely informational. Please only log this but do not use for your checks
  "data": [object]    // contains actionable result of processing if present
}
```

While we generally recommend that developers use HTTP status codes to determine the result of an API call, we have provided a handy status key to let you know upfront if the request was successful or not.

The message key is a string which will contain a summary of the response and its status. For instance when trying to retrieve a list of recipients, message might read “Recipients retrieved”. In the event of an error, the message key will contain a description of the error as with the authorization header situation above. This is the only key that is universal across requests.

The data key is where you want to look at for the result of your request. It can either be an object, or an array depending on the request made. For instance, a request to retrieve a single recipient will return a recipient object in the data key, while the key would be an array of recipients if a list is requested instead.

The meta key is used to provide context for the contents of the data key. For instance, when retrieving the list of transactions, pagination parameters can be passed along to limit the result set. The meta key will then contain an object with the following attributes:

Meta Key Structure

```json
"meta": {
  "total": 2,
  "perPage": 50,
  "currentPage": 1,
  "pageCount": 1
}
```

## Keys

**total** number\
This is the total number of records.

**perPage** number\
This is the maximum number of records that will be returned per request.

**currentPage** number\
This is the current `page` being returned. This is dependent on what page was requested using the `page` query parameter. **Default: 1**

**pageCount** number\
This is how many pages in total are available for retrieval considering the maximum number of records returned per request (i.e. `perPage`). For context, if there are 101 records and `perPage` is 100, `pageCount` will have a value of 2.

## Errors

Lenco's API is RESTful and as such, uses conventional HTTP response codes to indicate the success or failure of requests.\
The common error codes can be found below:

**200, 201**\
Request was successful and intended action was carried out. Note that we will always send a 200 if a transfer or collection request was made. Do check the data object to know how the request went (i.e. successful or failed).

**400**\
A validation or client side error occurred and the request was not fulfilled.

**401**\
The request was not authorized. This can be triggered by passing an invalid API token in the authorization header or the lack of one.

**404**\
Request could not be fulfilled as the request resource does not exist.

**500, 501, 502, 503, 504**\
Request could not be fulfilled due to an error on Lenco's end. This shouldn't happen so please report as soon as you encounter any instance of this.

<br />

If the HTTP response code is not 200 (or 201), the response would optionally include `errorCode`.\
Possible values for `errorCode` is given in the table below.

| Error Code | Details                                                                    |
| :--------- | :------------------------------------------------------------------------- |
| 01         | Validation error. One or more parameters could not be validated correctly. |
| 02         | Insufficient funds in account                                              |
| 03         | The transfer limit on the account has been exceeded                        |
| 04         | Invalid or duplicate reference                                             |
| 05         | Invalid recipient account                                                  |
| 06         | Restriction on debit account                                               |
| 07         | Invalid or duplicate bulk transfer reference                               |
| 08         | Invalid number of objects in bulk transfer `transfers` parameter           |
| 09         | Invalid auth token or authorization denied                                 |
| 10         | General error                                                              |
| 11         | Resource not found                                                         |
| 12         | Invalid mobile number                                                      |
| 13         | Access to resource denied                                                  |


Accept Payments

# Accept Payments

Lenco provides a simple and convenient payment flow for web with the popup widget. It can be integrated in a few easy steps.

### Step 1: Collect customer information

To begin, you need to pass information such as email, amount, reference, etc.\
Here is the full list of parameters you can pass:

[block:parameters]
{
  "data": {
    "h-0": "Param",
    "h-1": "Required?",
    "h-2": "Description",
    "0-0": "key",
    "0-1": "Yes",
    "0-2": "Your public key from Lenco",
    "1-0": "email",
    "1-1": "Yes",
    "1-2": "Email address of customer",
    "2-0": "reference",
    "2-1": "Yes",
    "2-2": "Unique case sensitive reference. Only `-`, `.`, `_`, and alphanumeric characters allowed",
    "3-0": "amount",
    "3-1": "Yes",
    "3-2": "Amount the customer is to pay. This can include decimals (i.e. 10.75)",
    "4-0": "currency",
    "4-1": "No",
    "4-2": "ISO 3-Letter Currency Code e.g. `ZMW`, `USD`",
    "5-0": "label",
    "5-1": "No",
    "5-2": "Text to show on the widget. This could be the name of the checkout form.",
    "6-0": "bearer",
    "6-1": "No",
    "6-2": "Decide who will bear the fee. Either `merchant` (you), or `customer` (your customer).  \nNote: This will only be used if not already set in your dashboard.",
    "7-0": "channels",
    "7-1": "No",
    "7-2": "An array of payment channels to control what is made available to the customer to make a payment with.  \nAvailable channels include: [`card`, `mobile-money`]",
    "8-0": "customer",
    "8-1": "No",
    "8-2": "This field holds the customer details",
    "9-0": "customer.firstName",
    "9-1": "No",
    "9-2": "The first name of the customer",
    "10-0": "customer.lastName",
    "10-1": "No",
    "10-2": "The last name of the customer",
    "11-0": "customer.phone",
    "11-1": "No",
    "11-2": "The phone number of the customer",
    "12-0": "billing",
    "12-1": "No",
    "12-2": "This field holds the customer's billing address",
    "13-0": "billing.streetAddress",
    "13-1": "No",
    "13-2": "The street address",
    "14-0": "billing.city",
    "14-1": "No",
    "14-2": "The city ",
    "15-0": "billing.state",
    "15-1": "No",
    "15-2": "The state or province.  \nIf a country does not have states or provinces, this can be left blank.  \n  \nNote: For US states and Canada provinces, this should be the 2-letter code for the state / province. i.e. California should be `CA`.  \n  \nYou can find the list of US State and Canada Province codes [here](https://www.ups.com/worldshiphelp/WSA/ENU/AppHelp/mergedProjects/CORE/Codes/State_Province_Codes.htm)",
    "16-0": "billing.postalCode",
    "16-1": "No",
    "16-2": "The postal code",
    "17-0": "billing.country",
    "17-1": "No",
    "17-2": "2-letter code i.e. United states should be `US`.  \nYou can find the list of country codes [here](https://www.iban.com/country-codes)",
    "18-0": "onSuccess",
    "18-1": "No",
    "18-2": "Javascript function that runs when payment is successful. This should ideally be a script that uses the verify endpoint to check the status of the payment.",
    "19-0": "onClose",
    "19-1": "No",
    "19-2": "Javascript function that is called if the customer closes the payment window instead of making a payment.",
    "20-0": "onConfirmationPending",
    "20-1": "No",
    "20-2": "Javascript function that is called if the customer closes the payment window before we verify their payment."
  },
  "cols": 3,
  "rows": 21,
  "align": [
    "left",
    "left",
    "left"
  ]
}
[/block]

<br />

### Step 2: Initiate the Payment

When you have all the details needed to initiate the payment, the next step is to pass them to Lenco to display the popup widget.

```html
<script src="https://pay.lenco.co/js/v1/inline.js"></script>

<script>
function getPaidWithLenco() {
    LencoPay.getPaid({
        key: 'YOUR_PUBLIC_KEY', // your Lenco public key
        reference: 'ref-' + Date.now(), // a unique reference you generated
        email: 'customer@email.com', // the customer's email address
        amount: 1000, // the amount the customer is to pay
        currency: "ZMW",
        channels: ["card", "mobile-money"],
        customer: {
            firstName: "John",
            lastName: "Doe",
            phone: "0971111111",
        },
        onSuccess: function (response) {
            //this happens after the payment is completed successfully
            const reference = response.reference;
            alert('Payment complete! Reference: ' + reference);
            // Make an AJAX call to your server with the reference to verify the payment
        },
        onClose: function () {
            alert('Payment was not completed, window closed.');
        },
        onConfirmationPending: function () {
            alert('Your purchase will be completed when the payment is confirmed');
        },
    });
}
</script>

```

For the sandbox environment, use `https://pay.sandbox.lenco.co/js/v1/inline.js` as the source for the lenco widget script.

**Important Notes:**

1. The `key` field takes your Lenco **public** key.
2. The `amount` field should not be converted to the lowest currency unit. Rather you can pass in a number with decimal places i.e. 10.75
3. It is ideal to generate a unique reference from your system for every payment to avoid duplicate attempts.
4. The `onSuccess` callback function is called when payment has been completed successfully. See the next section for how to handle the callback.
5. The `onClose` callback function is called if the user closes the widget without completing payment.
6. The `onConfirmationPending` callback function is called if the customer closes the payment window before we verify their payment.

<br />

### Step 3: Handle the `onSuccess` callback method

The `onSuccess` callback function is fired when the payment is successful. This is where you include any action you want to perform when the payment is successful.

The recommended next step here is to verify the payment as detailed in step 4.

> 📘
>
> **Note**\
> To verify the payment, you have to set up a route or page on your server that you pass the reference to. Then from your server, you call the verify endpoint to confirm the statis of the payment, and the response is returned to your frontend.

There are 2 ways you can call your server from the callback function

1. Make an AJAX request to the endpoint on your server that handles the payment verification

```javascript
onSuccess: function(response){
    $.ajax({
        url: 'https://www.yoururl.com/verify_payment?reference=' + response.reference,
        method: 'get',
        success: function (response) {
            // the payment status is in response.data.status
        } 
    });
}
```

2. Redirect to the verification endpoint URL on your server.

```javascript
onSuccess: function(response) {
    window.location = "https://www.yoururl.com/verify_payment.php?reference=" + response.reference;
}
// On the redirected page, you can call Lenco's API to verify the payment.
```

> ❗️
>
> **Warning**\
> Never call the Lenco API directly from your frontend to avoid exposing your api secret key on the frontend. All requests to the Lenco API should be initiated from your server, and your frontend gets the response from your server.

<br />

### Step 4: Verify the Payment

You do this by making a GET request to `https://api.lenco.co/access/v2/collections/status/:reference` from your server using your reference. You can find more information about this endpoint [here](https://lenco-api.readme.io/v2.0/reference/get-collection-by-reference).

```curl
# Sample Request

curl https://api.lenco.co/access/v2/collections/status/ref-1
-H "Authorization: Bearer API_SECRET_KEY"
-X GET
```
```json
// Sample Response

{
  "status": true,
  "message": "",
  "data": {
    "id": "d7bd9ccb-0737-4e72-a387-d00454341f21",
    "initiatedAt": "2024-03-12T07:06:11.562Z",
    "completedAt": "2024-03-12T07:14:10.412Z",
    "amount": "10.00",
    "fee": "0.25",
    "bearer": "merchant",
    "currency": "ZMW",
    "reference": "ref-1",
    "lencoReference": "240720004",
    "type": "mobile-money",
    "status": "successful",
    "source": "api",
    "reasonForFailure": null,
    "settlementStatus": "settled",
    "settlement": {
      "id": "c04583d7-d026-4dfa-b8b5-e96f17f93bb8",
      "amountSettled": "9.75",
      "currency": "ZMW",
      "createdAt": "2024-03-12T07:14:10.439Z",
      "settledAt": "2024-03-12T07:14:10.496Z",
      "status": "settled",
      "type": "instant",
      "accountId": "68f11209-451f-4a15-bfcd-d916eb8b09f4"
    },
    "mobileMoneyDetails": {
      "country": "zm",
      "phone": "0977433571",
      "operator": "airtel",
      "accountName": "Beata Jean",
      "operatorTransactionId": "MP240312.0000.A00001"
    },
    "bankAccountDetails": null,
    "cardDetails": null
  }
}
```

<br />

### Step 5: Handle webhook

When a payment is successful, Lenco sends a `collection.successful` webhook event to your webhook URL. You can [learn more here](https://lenco-api.readme.io/v2.0/reference/webhooks).

Test Cards and Accounts

# Test Cards and Accounts

### Mobile Money Test Accounts

Here are some mobile money accounts to test collections in the sandbox environment

| Phone      | Operator    | Response   | Error                            |
| :--------- | :---------- | :--------- | :------------------------------- |
| 0961111111 | mtn         | Successful |                                  |
| 0962222222 | mtn         | Failed     | Not enough funds                 |
| 0963333333 | mtn         | Failed     | Withdrawal amount limit exceeded |
| 0964444444 | mtn         | Failed     | Transaction unauthorized         |
| 0965555555 | mtn         | Failed     | Transaction unauthorized         |
| 0966666666 | mtn         | Failed     | Transaction Timed Out            |
| 0971111111 | airtel (zm) | Successful |                                  |
| 0972222222 | airtel (zm) | Failed     | Incorrect Pin                    |
| 0973333333 | airtel (zm) | Failed     | Invalid Amount                   |
| 0974444444 | airtel (zm) | Failed     | Payment invalid                  |
| 0975555555 | airtel (zm) | Failed     | Not enough funds                 |
| 0976666666 | airtel (zm) | Failed     | Failed                           |
| 0977777777 | airtel (zm) | Failed     | Transaction Timed Out            |
| 0978888888 | airtel (zm) | Failed     | Failed                           |
| 0881111111 | tnm         | Successful |                                  |
| 0883333333 | tnm         | Failed     | Not enough funds                 |
| 0885555555 | tnm         | Failed     | Transaction unauthorized         |
| 0991111111 | airtel (mw) | Successful |                                  |
| 0992222222 | airtel (mw) | Failed     | Not enough funds                 |
| 0984444444 | airtel (mw) | Failed     | Transaction unauthorized         |

<br />

### Test Cards

Here are some cards you can use in the sandbox environment

| Type       | Number              | CVV                     | Expiry                 |
| :--------- | :------------------ | :---------------------- | :--------------------- |
| Visa       | 4622 9431 2701 3705 | 838                     | Any date in the future |
| Visa       | 4622 9431 2701 3747 | 370                     | Any date in the future |
| Mastercard | 5555 5555 5555 4444 | Any 3-digit combination | Any date in the future |

/accounts

# /accounts

Retrieve information about your bank accounts

Response schema:

```json
{
    "status": boolean,
    "message": string,
    "data": [
        {
            "id": string,
            "details": {
                "type": string,
                "accountName": string,
                "tillNumber": string
            },
        "type": string,
        "status": string,
        "createdAt": date-time,
            "currency": string,
            "availableBalance": string | null,
            "ledgerBalance": string | null
      }
    ],
    "meta": {
        "total": number,
        "pageCount": number,
        "perPage": number,
        "currentPage": number
    }
}
```

> 📘 date-time
>
> All date-time fields are expressed in ISO8601 UTC times.

# OpenAPI definition

```json
{
  "openapi": "3.1.0",
  "info": {
    "title": "Lenco API",
    "version": "2.0"
  },
  "servers": [
    {
      "url": "https://api.lenco.co/access/v2"
    }
  ],
  "components": {
    "securitySchemes": {
      "sec0": {
        "type": "apiKey",
        "in": "header",
        "name": "Authorization",
        "x-bearer-format": "bearer",
        "x-default": "xo+CAiijrIy9XvZCYyhjrv0fpSAL6CfU8CgA+up1NXqK"
      }
    }
  },
  "security": [
    {
      "sec0": []
    }
  ],
  "paths": {
    "/accounts": {
      "get": {
        "summary": "/accounts",
        "description": "Retrieve information about your bank accounts",
        "operationId": "get-accounts",
        "parameters": [
          {
            "name": "page",
            "in": "query",
            "description": "If not specified, it defaults to 1",
            "schema": {
              "type": "integer",
              "format": "int32",
              "default": 1
            }
          }
        ],
        "responses": {
          "200": {
            "description": "200",
            "content": {
              "application/json": {
                "examples": {
                  "Result": {
                    "value": "{\n    \"status\": true,\n    \"message\": \"\",\n    \"data\": [\n        {\n            \"id\": \"b176cda5-7d97-4a3f-b4dd-ab0234e9e08c\",\n            \"details\": {\n                \"type\": \"lenco-merchant\",\n                \"accountName\": \"Account Name\",\n                \"tillNumber\": \"0000001\"\n            },\n            \"type\": \"Lenco Merchant\",\n            \"status\": \"active\",\n            \"createdAt\": \"2024-01-01T00:00:00.000Z\",\n            \"currency\": \"ZMW\",\n            \"availableBalance\": \"0.00\",\n            \"ledgerBalance\": \"0.00\"\n        }\n    ],\n    \"meta\": {\n        \"total\": 1,\n        \"pageCount\": 1,\n        \"perPage\": 100,\n        \"currentPage\": 1\n    }\n}"
                  }
                },
                "schema": {
                  "type": "object",
                  "properties": {
                    "status": {
                      "type": "boolean",
                      "example": true,
                      "default": true
                    },
                    "message": {
                      "type": "string",
                      "example": ""
                    },
                    "data": {
                      "type": "array",
                      "items": {
                        "type": "object",
                        "properties": {
                          "id": {
                            "type": "string",
                            "example": "b176cda5-7d97-4a3f-b4dd-ab0234e9e08c"
                          },
                          "details": {
                            "type": "object",
                            "properties": {
                              "type": {
                                "type": "string",
                                "example": "lenco-merchant"
                              },
                              "accountName": {
                                "type": "string",
                                "example": "Account Name"
                              },
                              "tillNumber": {
                                "type": "string",
                                "example": "0000001"
                              }
                            }
                          },
                          "type": {
                            "type": "string",
                            "example": "Lenco Merchant"
                          },
                          "status": {
                            "type": "string",
                            "example": "active"
                          },
                          "createdAt": {
                            "type": "string",
                            "example": "2024-01-01T00:00:00.000Z"
                          },
                          "currency": {
                            "type": "string",
                            "example": "ZMW"
                          },
                          "availableBalance": {
                            "type": "string",
                            "example": "0.00"
                          },
                          "ledgerBalance": {
                            "type": "string",
                            "example": "0.00"
                          }
                        }
                      }
                    },
                    "meta": {
                      "type": "object",
                      "properties": {
                        "total": {
                          "type": "integer",
                          "example": 1,
                          "default": 0
                        },
                        "pageCount": {
                          "type": "integer",
                          "example": 1,
                          "default": 0
                        },
                        "perPage": {
                          "type": "integer",
                          "example": 100,
                          "default": 0
                        },
                        "currentPage": {
                          "type": "integer",
                          "example": 1,
                          "default": 0
                        }
                      }
                    }
                  }
                }
              }
            }
          }
        },
        "deprecated": false
      }
    }
  },
  "x-readme": {
    "headers": [],
    "explorer-enabled": false,
    "proxy-enabled": true
  },
  "x-readme-fauxas": true,
  "_id": "65f06b6583c5de0051b8aa08:65f06b6583c5de0051b8aa0c"
}
```

/accounts/:id

# /accounts/:id

Retrieve information about a specific bank account

Response schema:

```json
{
    "status": boolean,
    "message": string,
    "data": {
        "id": string,
        "details": {
            "type": string,
            "accountName": string,
            "tillNumber": string
        },
        "type": string,
        "status": string,
        "createdAt": date-time,
        "currency": string,
        "availableBalance": string | null,
        "ledgerBalance": string | null
    }
}
```

# OpenAPI definition

```json
{
  "openapi": "3.1.0",
  "info": {
    "title": "Lenco API",
    "version": "2.0"
  },
  "servers": [
    {
      "url": "https://api.lenco.co/access/v2"
    }
  ],
  "components": {
    "securitySchemes": {
      "sec0": {
        "type": "apiKey",
        "in": "header",
        "name": "Authorization",
        "x-bearer-format": "bearer",
        "x-default": "xo+CAiijrIy9XvZCYyhjrv0fpSAL6CfU8CgA+up1NXqK"
      }
    }
  },
  "security": [
    {
      "sec0": []
    }
  ],
  "paths": {
    "/accounts/{id}": {
      "get": {
        "summary": "/accounts/:id",
        "description": "Retrieve information about a specific bank account",
        "operationId": "get-account-by-id",
        "parameters": [
          {
            "name": "id",
            "in": "path",
            "description": "Your 36-character account uuid.",
            "schema": {
              "type": "string"
            },
            "required": true
          }
        ],
        "responses": {
          "200": {
            "description": "200",
            "content": {
              "application/json": {
                "examples": {
                  "Result": {
                    "value": "{\n    \"status\": true,\n    \"message\": \"\",\n    \"data\": {\n        \"id\": \"b176cda5-7d97-4a3f-b4dd-ab0234e9e08c\",\n        \"details\": {\n            \"type\": \"lenco-merchant\",\n            \"accountName\": \"Account Name\",\n            \"tillNumber\": \"0000001\"\n        },\n        \"type\": \"Lenco Merchant\",\n        \"status\": \"active\",\n        \"createdAt\": \"2024-01-01T00:00:00.000Z\",\n        \"currency\": \"ZMW\",\n        \"availableBalance\": \"0.00\",\n        \"ledgerBalance\": \"0.00\"\n    }\n}"
                  }
                },
                "schema": {
                  "type": "object",
                  "properties": {
                    "status": {
                      "type": "boolean",
                      "example": true,
                      "default": true
                    },
                    "message": {
                      "type": "string",
                      "example": ""
                    },
                    "data": {
                      "type": "object",
                      "properties": {
                        "id": {
                          "type": "string",
                          "example": "b176cda5-7d97-4a3f-b4dd-ab0234e9e08c"
                        },
                        "details": {
                          "type": "object",
                          "properties": {
                            "type": {
                              "type": "string",
                              "example": "lenco-merchant"
                            },
                            "accountName": {
                              "type": "string",
                              "example": "Account Name"
                            },
                            "tillNumber": {
                              "type": "string",
                              "example": "0000001"
                            }
                          }
                        },
                        "type": {
                          "type": "string",
                          "example": "Lenco Merchant"
                        },
                        "status": {
                          "type": "string",
                          "example": "active"
                        },
                        "createdAt": {
                          "type": "string",
                          "example": "2024-01-01T00:00:00.000Z"
                        },
                        "currency": {
                          "type": "string",
                          "example": "ZMW"
                        },
                        "availableBalance": {
                          "type": "string",
                          "example": "0.00"
                        },
                        "ledgerBalance": {
                          "type": "string",
                          "example": "0.00"
                        }
                      }
                    }
                  }
                }
              }
            }
          },
          "400": {
            "description": "400",
            "content": {
              "application/json": {
                "examples": {
                  "Result": {
                    "value": "{\n    \"status\": false,\n    \"message\": \"Account was not found or api key does not have access to the account\",\n    \"data\": []\n}"
                  }
                },
                "schema": {
                  "type": "object",
                  "properties": {
                    "status": {
                      "type": "boolean",
                      "example": false,
                      "default": true
                    },
                    "message": {
                      "type": "string",
                      "example": "Account was not found or api key does not have access to the account"
                    },
                    "data": {
                      "type": "array",
                      "items": {
                        "type": "object",
                        "properties": {}
                      }
                    }
                  }
                }
              }
            }
          }
        },
        "deprecated": false
      }
    }
  },
  "x-readme": {
    "headers": [],
    "explorer-enabled": false,
    "proxy-enabled": true
  },
  "x-readme-fauxas": true,
  "_id": "65f06b6583c5de0051b8aa08:65f06b6583c5de0051b8aa0d"
}
```

/accounts/:id/balance

# /accounts/:id/balance

Retrieve account balance of a specific bank account

Response schema:

```json
{
    "status": boolean,
    "message": string,
    "data": {
        "availableBalance": string,
        "ledgerBalance": string,
        "currency": string,
    }
}
```

# OpenAPI definition

```json
{
  "openapi": "3.1.0",
  "info": {
    "title": "Lenco API",
    "version": "2.0"
  },
  "servers": [
    {
      "url": "https://api.lenco.co/access/v2"
    }
  ],
  "components": {
    "securitySchemes": {
      "sec0": {
        "type": "apiKey",
        "in": "header",
        "name": "Authorization",
        "x-bearer-format": "bearer",
        "x-default": "xo+CAiijrIy9XvZCYyhjrv0fpSAL6CfU8CgA+up1NXqK"
      }
    }
  },
  "security": [
    {
      "sec0": []
    }
  ],
  "paths": {
    "/accounts/{id}/balance": {
      "get": {
        "summary": "/accounts/:id/balance",
        "description": "Retrieve account balance of a specific bank account",
        "operationId": "get-account-balance",
        "parameters": [
          {
            "name": "id",
            "in": "path",
            "description": "Your 36-character account uuid.",
            "schema": {
              "type": "string"
            },
            "required": true
          }
        ],
        "responses": {
          "200": {
            "description": "200",
            "content": {
              "application/json": {
                "examples": {
                  "Result": {
                    "value": "{\n    \"status\": true,\n    \"message\": \"\",\n    \"data\": {\n        \"currency\": \"ZMW\",\n        \"availableBalance\": \"0.00\",\n        \"ledgerBalance\": \"0.00\"\n    }\n}"
                  }
                },
                "schema": {
                  "type": "object",
                  "properties": {
                    "status": {
                      "type": "boolean",
                      "example": true,
                      "default": true
                    },
                    "message": {
                      "type": "string",
                      "example": ""
                    },
                    "data": {
                      "type": "object",
                      "properties": {
                        "currency": {
                          "type": "string",
                          "example": "ZMW"
                        },
                        "availableBalance": {
                          "type": "string",
                          "example": "0.00"
                        },
                        "ledgerBalance": {
                          "type": "string",
                          "example": "0.00"
                        }
                      }
                    }
                  }
                }
              }
            }
          },
          "400": {
            "description": "400",
            "content": {
              "application/json": {
                "examples": {
                  "Result": {
                    "value": "{\n    \"status\": false,\n    \"message\": \"Account was not found or api key does not have access to the account\",\n    \"data\": []\n}"
                  }
                },
                "schema": {
                  "type": "object",
                  "properties": {
                    "status": {
                      "type": "boolean",
                      "example": false,
                      "default": true
                    },
                    "message": {
                      "type": "string",
                      "example": "Account was not found or api key does not have access to the account"
                    },
                    "data": {
                      "type": "array",
                      "items": {
                        "type": "object",
                        "properties": {}
                      }
                    }
                  }
                }
              }
            }
          }
        },
        "deprecated": false
      }
    }
  },
  "x-readme": {
    "headers": [],
    "explorer-enabled": false,
    "proxy-enabled": true
  },
  "x-readme-fauxas": true,
  "_id": "65f06b6583c5de0051b8aa08:65f06b6583c5de0051b8aa0e"
}
```

/banks

# /banks

Get list of banks and financial institutions

Response schema:

```json
{
    "status": boolean,
    "message": string,
    "data": [
        {
            "id": string,
            "name": string,
            "country": string
        }
    ]
}
```

# OpenAPI definition

```json
{
  "openapi": "3.1.0",
  "info": {
    "title": "Lenco API",
    "version": "2.0"
  },
  "servers": [
    {
      "url": "https://api.lenco.co/access/v2"
    }
  ],
  "components": {
    "securitySchemes": {
      "sec0": {
        "type": "apiKey",
        "in": "header",
        "name": "Authorization",
        "x-bearer-format": "bearer",
        "x-default": "xo+CAiijrIy9XvZCYyhjrv0fpSAL6CfU8CgA+up1NXqK"
      }
    }
  },
  "security": [
    {
      "sec0": []
    }
  ],
  "paths": {
    "/banks": {
      "get": {
        "summary": "/banks",
        "description": "Get list of banks and financial institutions",
        "operationId": "get-banks",
        "parameters": [
          {
            "name": "country",
            "in": "query",
            "description": "i.e. ng, zm",
            "schema": {
              "type": "string"
            }
          }
        ],
        "responses": {
          "200": {
            "description": "200",
            "content": {
              "application/json": {
                "examples": {
                  "Result": {
                    "value": "{\n    \"status\": true,\n    \"message\": \"\",\n    \"data\": [\n        {\n            \"id\": \"002\",\n            \"name\": \"Absa Bank\",\n            \"country\": \"zm\"\n        }\n    ]\n}"
                  }
                },
                "schema": {
                  "type": "object",
                  "properties": {
                    "status": {
                      "type": "boolean",
                      "example": true,
                      "default": true
                    },
                    "message": {
                      "type": "string",
                      "example": ""
                    },
                    "data": {
                      "type": "array",
                      "items": {
                        "type": "object",
                        "properties": {
                          "id": {
                            "type": "string",
                            "example": "002"
                          },
                          "name": {
                            "type": "string",
                            "example": "Absa Bank"
                          },
                          "country": {
                            "type": "string",
                            "example": "zm"
                          }
                        }
                      }
                    }
                  }
                }
              }
            }
          }
        },
        "deprecated": false
      }
    }
  },
  "x-readme": {
    "headers": [],
    "explorer-enabled": false,
    "proxy-enabled": true
  },
  "x-readme-fauxas": true,
  "_id": "65f06b6583c5de0051b8aa08:65f06b6583c5de0051b8aa14"
}
```

/resolve/bank-account

# /resolve/bank-account

Verify/resolve account details

Response Schema:

```json
{
    "status": boolean,
    "message": string,
    "data": {
        "type": "bank-account",
        "accountName": string,
        "accountNumber": string,
        "bank": {
            "id": string,
            "name": string,
            "country": string
        }
    }
}
```

# OpenAPI definition

```json
{
  "openapi": "3.1.0",
  "info": {
    "title": "Lenco API",
    "version": "2.0"
  },
  "servers": [
    {
      "url": "https://api.lenco.co/access/v2"
    }
  ],
  "components": {
    "securitySchemes": {
      "sec0": {
        "type": "apiKey",
        "in": "header",
        "name": "Authorization",
        "x-bearer-format": "bearer",
        "x-default": "xo+CAiijrIy9XvZCYyhjrv0fpSAL6CfU8CgA+up1NXqK"
      }
    }
  },
  "security": [
    {
      "sec0": []
    }
  ],
  "paths": {
    "/resolve/bank-account": {
      "post": {
        "summary": "/resolve/bank-account",
        "description": "Verify/resolve account details",
        "operationId": "resolve-bank-account",
        "requestBody": {
          "content": {
            "application/json": {
              "schema": {
                "type": "object",
                "required": [
                  "accountNumber",
                  "bankId"
                ],
                "properties": {
                  "accountNumber": {
                    "type": "string"
                  },
                  "bankId": {
                    "type": "string"
                  },
                  "country": {
                    "type": "string",
                    "description": "Optional. i.e `ng`, `zm`"
                  }
                }
              }
            }
          }
        },
        "responses": {
          "200": {
            "description": "200",
            "content": {
              "application/json": {
                "examples": {
                  "Result": {
                    "value": "{\n    \"status\": true,\n    \"message\": \"\",\n    \"data\": {\n        \"type\": \"bank-account\",\n        \"accountName\": \"Beata Jean\",\n        \"accountNumber\": \"9130000000000\",\n        \"bank\": {\n            \"id\": \"002\",\n            \"name\": \"Absa Bank\",\n            \"country\": \"zm\"\n        }\n    }\n}"
                  }
                },
                "schema": {
                  "type": "object",
                  "properties": {
                    "status": {
                      "type": "boolean",
                      "example": true,
                      "default": true
                    },
                    "message": {
                      "type": "string",
                      "example": ""
                    },
                    "data": {
                      "type": "object",
                      "properties": {
                        "type": {
                          "type": "string",
                          "example": "bank-account"
                        },
                        "accountName": {
                          "type": "string",
                          "example": "Beata Jean"
                        },
                        "accountNumber": {
                          "type": "string",
                          "example": "9130000000000"
                        },
                        "bank": {
                          "type": "object",
                          "properties": {
                            "id": {
                              "type": "string",
                              "example": "002"
                            },
                            "name": {
                              "type": "string",
                              "example": "Absa Bank"
                            },
                            "country": {
                              "type": "string",
                              "example": "zm"
                            }
                          }
                        }
                      }
                    }
                  }
                }
              }
            }
          },
          "400": {
            "description": "400",
            "content": {
              "application/json": {
                "examples": {
                  "Result": {
                    "value": "{\n    \"status\": false,\n    \"message\": \"Account details was not found\",\n    \"data\": null\n}"
                  }
                },
                "schema": {
                  "type": "object",
                  "properties": {
                    "status": {
                      "type": "boolean",
                      "example": false,
                      "default": true
                    },
                    "message": {
                      "type": "string",
                      "example": "Account details was not found"
                    },
                    "data": {}
                  }
                }
              }
            }
          }
        },
        "deprecated": false
      }
    }
  },
  "x-readme": {
    "headers": [],
    "explorer-enabled": false,
    "proxy-enabled": true
  },
  "x-readme-fauxas": true,
  "_id": "65f06b6583c5de0051b8aa08:65f06b6583c5de0051b8aa16"
}
```


/resolve/mobile-money

# /resolve/mobile-money

Response Schema:

```json
{
    "status": boolean,
    "message": string,
    "data": {
        "type": "mobile-money",
        "accountName": string,
        "phone": string,
        "operator": string,
        "country": string
    }
}
```

# OpenAPI definition

```json
{
  "openapi": "3.1.0",
  "info": {
    "title": "Lenco API",
    "version": "2.0"
  },
  "servers": [
    {
      "url": "https://api.lenco.co/access/v2"
    }
  ],
  "components": {
    "securitySchemes": {
      "sec0": {
        "type": "apiKey",
        "in": "header",
        "name": "Authorization",
        "x-bearer-format": "bearer",
        "x-default": "xo+CAiijrIy9XvZCYyhjrv0fpSAL6CfU8CgA+up1NXqK"
      }
    }
  },
  "security": [
    {
      "sec0": []
    }
  ],
  "paths": {
    "/resolve/mobile-money": {
      "post": {
        "summary": "/resolve/mobile-money",
        "description": "",
        "operationId": "resolve-mobile-money-account",
        "requestBody": {
          "content": {
            "application/json": {
              "schema": {
                "type": "object",
                "required": [
                  "phone",
                  "operator"
                ],
                "properties": {
                  "phone": {
                    "type": "string"
                  },
                  "operator": {
                    "type": "string",
                    "description": "either `mtn`, `airtel`, or `zamtel`",
                    "enum": [
                      "airtel",
                      "mtn",
                      "zamtel"
                    ]
                  },
                  "country": {
                    "type": "string",
                    "description": "Optional. Currently supporting only `zm`",
                    "enum": [
                      "zm"
                    ]
                  }
                }
              },
              "examples": {
                "Request Example": {
                  "value": {
                    "phone": "0961111111",
                    "operator": "mtn",
                    "country": "zm"
                  }
                }
              }
            }
          }
        },
        "responses": {
          "200": {
            "description": "200",
            "content": {
              "application/json": {
                "examples": {
                  "Result": {
                    "value": "{\n    \"status\": true,\n    \"message\": \"\",\n    \"data\": {\n        \"type\": \"mobile-money\",\n        \"accountName\": \"Beata Jean\",\n        \"phone\": \"0750000000\",\n        \"operator\": \"zamtel\",\n        \"country\": \"zm\"\n    }\n}"
                  }
                },
                "schema": {
                  "type": "object",
                  "properties": {
                    "status": {
                      "type": "boolean",
                      "example": true,
                      "default": true
                    },
                    "message": {
                      "type": "string",
                      "example": ""
                    },
                    "data": {
                      "type": "object",
                      "properties": {
                        "type": {
                          "type": "string",
                          "example": "mobile-money"
                        },
                        "accountName": {
                          "type": "string",
                          "example": "Beata Jean"
                        },
                        "phone": {
                          "type": "string",
                          "example": "0750000000"
                        },
                        "operator": {
                          "type": "string",
                          "example": "zamtel"
                        },
                        "country": {
                          "type": "string",
                          "example": "zm"
                        }
                      }
                    }
                  }
                }
              }
            }
          },
          "400": {
            "description": "400",
            "content": {
              "application/json": {
                "examples": {
                  "Result": {
                    "value": "{\n    \"status\": false,\n    \"message\": \"Account details was not found\",\n    \"data\": null\n}"
                  }
                },
                "schema": {
                  "type": "object",
                  "properties": {
                    "status": {
                      "type": "boolean",
                      "example": false,
                      "default": true
                    },
                    "message": {
                      "type": "string",
                      "example": "Account details was not found"
                    },
                    "data": {}
                  }
                }
              }
            }
          }
        },
        "deprecated": false
      }
    }
  },
  "x-readme": {
    "headers": [],
    "explorer-enabled": false,
    "proxy-enabled": true
  },
  "x-readme-fauxas": true,
  "_id": "65f06b6583c5de0051b8aa08:65f19d984120a1001d1d60f4"
}
```

/resolve/lenco-money

# /resolve/lenco-money

Response Schema:

```json
{
    "status": boolean,
    "message": string,
    "data": {
        "type": "lenco-money",
        "accountName": string,
        "walletNumber": string
    }
}
```

# OpenAPI definition

```json
{
  "openapi": "3.1.0",
  "info": {
    "title": "Lenco API",
    "version": "2.0"
  },
  "servers": [
    {
      "url": "https://api.lenco.co/access/v2"
    }
  ],
  "components": {
    "securitySchemes": {
      "sec0": {
        "type": "apiKey",
        "in": "header",
        "name": "Authorization",
        "x-bearer-format": "bearer",
        "x-default": "xo+CAiijrIy9XvZCYyhjrv0fpSAL6CfU8CgA+up1NXqK"
      }
    }
  },
  "security": [
    {
      "sec0": []
    }
  ],
  "paths": {
    "/resolve/lenco-money": {
      "post": {
        "summary": "/resolve/lenco-money",
        "description": "",
        "operationId": "resolve-lenco-money-account",
        "requestBody": {
          "content": {
            "application/json": {
              "schema": {
                "type": "object",
                "required": [
                  "walletNumber"
                ],
                "properties": {
                  "walletNumber": {
                    "type": "string"
                  }
                }
              }
            }
          }
        },
        "responses": {
          "200": {
            "description": "200",
            "content": {
              "application/json": {
                "examples": {
                  "Result": {
                    "value": "{\n    \"status\": true,\n    \"message\": \"\",\n    \"data\": {\n        \"type\": \"lenco-money\",\n        \"accountName\": \"Beata Jean\",\n        \"walletNumber\": \"0000001\"\n    }\n}"
                  }
                },
                "schema": {
                  "type": "object",
                  "properties": {
                    "status": {
                      "type": "boolean",
                      "example": true,
                      "default": true
                    },
                    "message": {
                      "type": "string",
                      "example": ""
                    },
                    "data": {
                      "type": "object",
                      "properties": {
                        "type": {
                          "type": "string",
                          "example": "lenco-money"
                        },
                        "accountName": {
                          "type": "string",
                          "example": "Beata Jean"
                        },
                        "walletNumber": {
                          "type": "string",
                          "example": "0000001"
                        }
                      }
                    }
                  }
                }
              }
            }
          },
          "400": {
            "description": "400",
            "content": {
              "application/json": {
                "examples": {
                  "Result": {
                    "value": "{\n    \"status\": false,\n    \"message\": \"Account details was not found\",\n    \"data\": null\n}"
                  }
                },
                "schema": {
                  "type": "object",
                  "properties": {
                    "status": {
                      "type": "boolean",
                      "example": false,
                      "default": true
                    },
                    "message": {
                      "type": "string",
                      "example": "Account details was not found"
                    },
                    "data": {}
                  }
                }
              }
            }
          }
        },
        "deprecated": false
      }
    }
  },
  "x-readme": {
    "headers": [],
    "explorer-enabled": false,
    "proxy-enabled": true
  },
  "x-readme-fauxas": true,
  "_id": "65f06b6583c5de0051b8aa08:65f19da74120a1001d1d6100"
}
```


/resolve/lenco-merchant

# /resolve/lenco-merchant

Response Schema:

```json
{
    "status": boolean,
    "message": string,
    "data": {
        "type": "lenco-merchant",
        "accountName": string,
        "tillNumber": string
    }
}
```

# OpenAPI definition

```json
{
  "openapi": "3.1.0",
  "info": {
    "title": "Lenco API",
    "version": "2.0"
  },
  "servers": [
    {
      "url": "https://api.lenco.co/access/v2"
    }
  ],
  "components": {
    "securitySchemes": {
      "sec0": {
        "type": "apiKey",
        "in": "header",
        "name": "Authorization",
        "x-bearer-format": "bearer",
        "x-default": "xo+CAiijrIy9XvZCYyhjrv0fpSAL6CfU8CgA+up1NXqK"
      }
    }
  },
  "security": [
    {
      "sec0": []
    }
  ],
  "paths": {
    "/resolve/lenco-merchant": {
      "post": {
        "summary": "/resolve/lenco-merchant",
        "description": "",
        "operationId": "resolve-lenco-merchant-account",
        "requestBody": {
          "content": {
            "application/json": {
              "schema": {
                "type": "object",
                "required": [
                  "tillNumber"
                ],
                "properties": {
                  "tillNumber": {
                    "type": "string"
                  }
                }
              }
            }
          }
        },
        "responses": {
          "200": {
            "description": "200",
            "content": {
              "application/json": {
                "examples": {
                  "Result": {
                    "value": "{\n    \"status\": true,\n    \"message\": \"\",\n    \"data\": {\n        \"type\": \"lenco-merchant\",\n        \"accountName\": \"Account Name\",\n        \"tillNumber\": \"0000001\"\n    }\n}"
                  }
                },
                "schema": {
                  "type": "object",
                  "properties": {
                    "status": {
                      "type": "boolean",
                      "example": true,
                      "default": true
                    },
                    "message": {
                      "type": "string",
                      "example": ""
                    },
                    "data": {
                      "type": "object",
                      "properties": {
                        "type": {
                          "type": "string",
                          "example": "lenco-merchant"
                        },
                        "accountName": {
                          "type": "string",
                          "example": "Account Name"
                        },
                        "tillNumber": {
                          "type": "string",
                          "example": "0000001"
                        }
                      }
                    }
                  }
                }
              }
            }
          },
          "400": {
            "description": "400",
            "content": {
              "application/json": {
                "examples": {
                  "Result": {
                    "value": "{\n    \"status\": false,\n    \"message\": \"Account details was not found\",\n    \"data\": null\n}"
                  }
                },
                "schema": {
                  "type": "object",
                  "properties": {
                    "status": {
                      "type": "boolean",
                      "example": false,
                      "default": true
                    },
                    "message": {
                      "type": "string",
                      "example": "Account details was not found"
                    },
                    "data": {}
                  }
                }
              }
            }
          }
        },
        "deprecated": false
      }
    }
  },
  "x-readme": {
    "headers": [],
    "explorer-enabled": false,
    "proxy-enabled": true
  },
  "x-readme-fauxas": true,
  "_id": "65f06b6583c5de0051b8aa08:65f19db57bee5a00696ba004"
}
```

/transfer-recipients

# /transfer-recipients

Retrieve information about all your transfer recipients

Response schema:

```json
{
    "status": boolean,
    "message": string,
    "data": [
        {
            "id": string,
            "currency": string,
            "type": string,
            "country": string,
            "details": {
                "type": string,
                "accountName": string,
                "accountNumber": string | null,
                "bank": {
                    "id": string,
                    "name": string,
                    "country": string
                } | null,
                "phone": string | null,
                "operator": string | null,
                "walletNumber": string | null,
                "tillNumber": string | null
            }
        }
    ],
    "meta": {
        "total": number,
        "pageCount": number,
        "perPage": number,
        "currentPage": number
    }
}
```

# OpenAPI definition

```json
{
  "openapi": "3.1.0",
  "info": {
    "title": "Lenco API",
    "version": "2.0"
  },
  "servers": [
    {
      "url": "https://api.lenco.co/access/v2"
    }
  ],
  "components": {
    "securitySchemes": {
      "sec0": {
        "type": "apiKey",
        "in": "header",
        "name": "Authorization",
        "x-bearer-format": "bearer",
        "x-default": "xo+CAiijrIy9XvZCYyhjrv0fpSAL6CfU8CgA+up1NXqK"
      }
    }
  },
  "security": [
    {
      "sec0": []
    }
  ],
  "paths": {
    "/transfer-recipients": {
      "get": {
        "summary": "/transfer-recipients",
        "description": "Retrieve information about all your transfer recipients",
        "operationId": "get-transfer-recipients",
        "parameters": [
          {
            "name": "page",
            "in": "query",
            "description": "If not specified, it defaults to 1",
            "schema": {
              "type": "integer",
              "format": "int32",
              "default": 1
            }
          },
          {
            "name": "type",
            "in": "query",
            "description": "either `mobile-money`, `bank-account`, `lenco-money` or `lenco-merchant`",
            "schema": {
              "type": "string"
            }
          },
          {
            "name": "country",
            "in": "query",
            "description": "i.e. ng, zm",
            "schema": {
              "type": "string"
            }
          }
        ],
        "responses": {
          "200": {
            "description": "200",
            "content": {
              "application/json": {
                "examples": {
                  "Result": {
                    "value": "{\n    \"status\": true,\n    \"message\": \"\",\n    \"data\": [\n        {\n            \"id\": \"d6b6e00e-bdb6-43a6-a561-85b61496198e\",\n            \"details\": {\n                \"type\": \"mobile-money\",\n                \"accountName\": \"Beata Jean\",\n                \"phone\": \"0750000000\",\n                \"operator\": \"zamtel\"\n            },\n            \"currency\": \"ZMW\",\n            \"type\": \"mobile-money\",\n            \"country\": \"zm\"\n        }\n    ],\n    \"meta\": {\n        \"total\": 1,\n        \"pageCount\": 1,\n        \"perPage\": 100,\n        \"currentPage\": 1\n    }\n}"
                  }
                },
                "schema": {
                  "type": "object",
                  "properties": {
                    "status": {
                      "type": "boolean",
                      "example": true,
                      "default": true
                    },
                    "message": {
                      "type": "string",
                      "example": ""
                    },
                    "data": {
                      "type": "array",
                      "items": {
                        "type": "object",
                        "properties": {
                          "id": {
                            "type": "string",
                            "example": "d6b6e00e-bdb6-43a6-a561-85b61496198e"
                          },
                          "details": {
                            "type": "object",
                            "properties": {
                              "type": {
                                "type": "string",
                                "example": "mobile-money"
                              },
                              "accountName": {
                                "type": "string",
                                "example": "Beata Jean"
                              },
                              "phone": {
                                "type": "string",
                                "example": "0750000000"
                              },
                              "operator": {
                                "type": "string",
                                "example": "zamtel"
                              }
                            }
                          },
                          "currency": {
                            "type": "string",
                            "example": "ZMW"
                          },
                          "type": {
                            "type": "string",
                            "example": "mobile-money"
                          },
                          "country": {
                            "type": "string",
                            "example": "zm"
                          }
                        }
                      }
                    },
                    "meta": {
                      "type": "object",
                      "properties": {
                        "total": {
                          "type": "integer",
                          "example": 1,
                          "default": 0
                        },
                        "pageCount": {
                          "type": "integer",
                          "example": 1,
                          "default": 0
                        },
                        "perPage": {
                          "type": "integer",
                          "example": 100,
                          "default": 0
                        },
                        "currentPage": {
                          "type": "integer",
                          "example": 1,
                          "default": 0
                        }
                      }
                    }
                  }
                }
              }
            }
          }
        },
        "deprecated": false
      }
    }
  },
  "x-readme": {
    "headers": [],
    "explorer-enabled": false,
    "proxy-enabled": true
  },
  "x-readme-fauxas": true,
  "_id": "65f06b6583c5de0051b8aa08:65f06b6583c5de0051b8aa10"
}
```

/transfer-recipients/:id

# /transfer-recipients/:id

Retrieve information about a specific transfer recipient

Response schema:

```json
{
    "status": boolean,
    "message": string,
    "data": {
        "id": string,
        "currency": string,
        "type": string,
        "country": string,
        "details": {
            "type": string,
            "accountName": string,
            "accountNumber": string | null,
            "bank": {
                "id": string,
                "name": string,
                "country": string
            } | null,
            "phone": string | null,
            "operator": string | null,
            "walletNumber": string | null,
            "tillNumber": string | null
        }
    }
}
```

# OpenAPI definition

```json
{
  "openapi": "3.1.0",
  "info": {
    "title": "Lenco API",
    "version": "2.0"
  },
  "servers": [
    {
      "url": "https://api.lenco.co/access/v2"
    }
  ],
  "components": {
    "securitySchemes": {
      "sec0": {
        "type": "apiKey",
        "in": "header",
        "name": "Authorization",
        "x-bearer-format": "bearer",
        "x-default": "xo+CAiijrIy9XvZCYyhjrv0fpSAL6CfU8CgA+up1NXqK"
      }
    }
  },
  "security": [
    {
      "sec0": []
    }
  ],
  "paths": {
    "/transfer-recipients/{id}": {
      "get": {
        "summary": "/transfer-recipients/:id",
        "description": "Retrieve information about a specific transfer recipient",
        "operationId": "get-transfer-recipient-by-id",
        "parameters": [
          {
            "name": "id",
            "in": "path",
            "description": "Your 36-character recipient uuid.",
            "schema": {
              "type": "string"
            },
            "required": true
          }
        ],
        "responses": {
          "200": {
            "description": "200",
            "content": {
              "application/json": {
                "examples": {
                  "Result": {
                    "value": "{\n    \"status\": true,\n    \"message\": \"\",\n    \"data\": {\n        \"id\": \"d6b6e00e-bdb6-43a6-a561-85b61496198e\",\n        \"details\": {\n            \"type\": \"mobile-money\",\n            \"accountName\": \"Beata Jean\",\n            \"phone\": \"0750000000\",\n            \"operator\": \"zamtel\"\n        },\n        \"currency\": \"ZMW\",\n        \"type\": \"mobile-money\",\n        \"country\": \"zm\"\n    }\n}"
                  }
                },
                "schema": {
                  "type": "object",
                  "properties": {
                    "status": {
                      "type": "boolean",
                      "example": true,
                      "default": true
                    },
                    "message": {
                      "type": "string",
                      "example": ""
                    },
                    "data": {
                      "type": "object",
                      "properties": {
                        "id": {
                          "type": "string",
                          "example": "d6b6e00e-bdb6-43a6-a561-85b61496198e"
                        },
                        "details": {
                          "type": "object",
                          "properties": {
                            "type": {
                              "type": "string",
                              "example": "mobile-money"
                            },
                            "accountName": {
                              "type": "string",
                              "example": "Beata Jean"
                            },
                            "phone": {
                              "type": "string",
                              "example": "0750000000"
                            },
                            "operator": {
                              "type": "string",
                              "example": "zamtel"
                            }
                          }
                        },
                        "currency": {
                          "type": "string",
                          "example": "ZMW"
                        },
                        "type": {
                          "type": "string",
                          "example": "mobile-money"
                        },
                        "country": {
                          "type": "string",
                          "example": "zm"
                        }
                      }
                    }
                  }
                }
              }
            }
          },
          "400": {
            "description": "400",
            "content": {
              "application/json": {
                "examples": {
                  "Result": {
                    "value": "{\n    \"status\": false,\n    \"message\": \"Transfer Recipient was not found\",\n    \"data\": null\n}"
                  }
                },
                "schema": {
                  "type": "object",
                  "properties": {
                    "status": {
                      "type": "boolean",
                      "example": false,
                      "default": true
                    },
                    "message": {
                      "type": "string",
                      "example": "Transfer Recipient was not found"
                    },
                    "data": {}
                  }
                }
              }
            }
          }
        },
        "deprecated": false
      }
    }
  },
  "x-readme": {
    "headers": [],
    "explorer-enabled": false,
    "proxy-enabled": true
  },
  "x-readme-fauxas": true,
  "_id": "65f06b6583c5de0051b8aa08:65f06b6583c5de0051b8aa11"
}
```

/transfer-recipients/bank-account

# /transfer-recipients/bank-account

Create transfer recipient as a bank account

Response schema:

```json
{
    "status": boolean,
    "message": string,
    "data": {
        "id": string,
        "currency": string,
        "type": "string",
        "country": string,
        "details": {
            "type": "bank-account",
            "accountName": string,
            "accountNumber": string,
            "bank": {
                "id": string,
                "name": string,
                "country": string
            }
        }
    }
}
```

# OpenAPI definition

```json
{
  "openapi": "3.1.0",
  "info": {
    "title": "Lenco API",
    "version": "2.0"
  },
  "servers": [
    {
      "url": "https://api.lenco.co/access/v2"
    }
  ],
  "components": {
    "securitySchemes": {
      "sec0": {
        "type": "apiKey",
        "in": "header",
        "name": "Authorization",
        "x-bearer-format": "bearer",
        "x-default": "xo+CAiijrIy9XvZCYyhjrv0fpSAL6CfU8CgA+up1NXqK"
      }
    }
  },
  "security": [
    {
      "sec0": []
    }
  ],
  "paths": {
    "/transfer-recipients/bank-account": {
      "post": {
        "summary": "/transfer-recipients/bank-account",
        "description": "Create transfer recipient as a bank account",
        "operationId": "create-transfer-recipient-as-bank-account",
        "requestBody": {
          "content": {
            "application/json": {
              "schema": {
                "type": "object",
                "required": [
                  "accountNumber",
                  "bankId"
                ],
                "properties": {
                  "accountNumber": {
                    "type": "string"
                  },
                  "bankId": {
                    "type": "string"
                  },
                  "country": {
                    "type": "string",
                    "description": "Optional"
                  }
                }
              }
            }
          }
        },
        "responses": {
          "200": {
            "description": "200",
            "content": {
              "application/json": {
                "examples": {
                  "Result": {
                    "value": "{\n    \"status\": true,\n    \"message\": \"\",\n    \"data\": {\n        \"id\": \"d4f71d4a-eda4-4237-9976-5cbdc8a54cf3\",\n        \"details\": {\n            \"type\": \"bank-account\",\n            \"accountName\": \"Beata Jean\",\n            \"accountNumber\": \"9130000000000\",\n            \"bank\": {\n                \"id\": \"002\",\n                \"name\": \"Absa Bank\",\n                \"country\": \"zm\"\n            }\n        },\n        \"currency\": \"ZMW\",\n        \"type\": \"bank-account\",\n        \"country\": \"zm\"\n    }\n}"
                  }
                },
                "schema": {
                  "type": "object",
                  "properties": {
                    "status": {
                      "type": "boolean",
                      "example": true,
                      "default": true
                    },
                    "message": {
                      "type": "string",
                      "example": ""
                    },
                    "data": {
                      "type": "object",
                      "properties": {
                        "id": {
                          "type": "string",
                          "example": "d4f71d4a-eda4-4237-9976-5cbdc8a54cf3"
                        },
                        "details": {
                          "type": "object",
                          "properties": {
                            "type": {
                              "type": "string",
                              "example": "bank-account"
                            },
                            "accountName": {
                              "type": "string",
                              "example": "Beata Jean"
                            },
                            "accountNumber": {
                              "type": "string",
                              "example": "9130000000000"
                            },
                            "bank": {
                              "type": "object",
                              "properties": {
                                "id": {
                                  "type": "string",
                                  "example": "002"
                                },
                                "name": {
                                  "type": "string",
                                  "example": "Absa Bank"
                                },
                                "country": {
                                  "type": "string",
                                  "example": "zm"
                                }
                              }
                            }
                          }
                        },
                        "currency": {
                          "type": "string",
                          "example": "ZMW"
                        },
                        "type": {
                          "type": "string",
                          "example": "bank-account"
                        },
                        "country": {
                          "type": "string",
                          "example": "zm"
                        }
                      }
                    }
                  }
                }
              }
            }
          },
          "400": {
            "description": "400",
            "content": {
              "application/json": {
                "examples": {
                  "Result": {
                    "value": "{\n    \"status\": false,\n    \"message\": \"Account Details could not be verified\",\n    \"data\": null\n}"
                  }
                },
                "schema": {
                  "type": "object",
                  "properties": {
                    "status": {
                      "type": "boolean",
                      "example": false,
                      "default": true
                    },
                    "message": {
                      "type": "string",
                      "example": "Account Details could not be verified"
                    },
                    "data": {}
                  }
                }
              }
            }
          }
        },
        "deprecated": false
      }
    }
  },
  "x-readme": {
    "headers": [],
    "explorer-enabled": false,
    "proxy-enabled": true
  },
  "x-readme-fauxas": true,
  "_id": "65f06b6583c5de0051b8aa08:65f06b6583c5de0051b8aa12"
}
```

/transfer-recipients/bank-account

# /transfer-recipients/bank-account

Create transfer recipient as a bank account

Response schema:

```json
{
    "status": boolean,
    "message": string,
    "data": {
        "id": string,
        "currency": string,
        "type": "string",
        "country": string,
        "details": {
            "type": "bank-account",
            "accountName": string,
            "accountNumber": string,
            "bank": {
                "id": string,
                "name": string,
                "country": string
            }
        }
    }
}
```

# OpenAPI definition

```json
{
  "openapi": "3.1.0",
  "info": {
    "title": "Lenco API",
    "version": "2.0"
  },
  "servers": [
    {
      "url": "https://api.lenco.co/access/v2"
    }
  ],
  "components": {
    "securitySchemes": {
      "sec0": {
        "type": "apiKey",
        "in": "header",
        "name": "Authorization",
        "x-bearer-format": "bearer",
        "x-default": "xo+CAiijrIy9XvZCYyhjrv0fpSAL6CfU8CgA+up1NXqK"
      }
    }
  },
  "security": [
    {
      "sec0": []
    }
  ],
  "paths": {
    "/transfer-recipients/bank-account": {
      "post": {
        "summary": "/transfer-recipients/bank-account",
        "description": "Create transfer recipient as a bank account",
        "operationId": "create-transfer-recipient-as-bank-account",
        "requestBody": {
          "content": {
            "application/json": {
              "schema": {
                "type": "object",
                "required": [
                  "accountNumber",
                  "bankId"
                ],
                "properties": {
                  "accountNumber": {
                    "type": "string"
                  },
                  "bankId": {
                    "type": "string"
                  },
                  "country": {
                    "type": "string",
                    "description": "Optional"
                  }
                }
              }
            }
          }
        },
        "responses": {
          "200": {
            "description": "200",
            "content": {
              "application/json": {
                "examples": {
                  "Result": {
                    "value": "{\n    \"status\": true,\n    \"message\": \"\",\n    \"data\": {\n        \"id\": \"d4f71d4a-eda4-4237-9976-5cbdc8a54cf3\",\n        \"details\": {\n            \"type\": \"bank-account\",\n            \"accountName\": \"Beata Jean\",\n            \"accountNumber\": \"9130000000000\",\n            \"bank\": {\n                \"id\": \"002\",\n                \"name\": \"Absa Bank\",\n                \"country\": \"zm\"\n            }\n        },\n        \"currency\": \"ZMW\",\n        \"type\": \"bank-account\",\n        \"country\": \"zm\"\n    }\n}"
                  }
                },
                "schema": {
                  "type": "object",
                  "properties": {
                    "status": {
                      "type": "boolean",
                      "example": true,
                      "default": true
                    },
                    "message": {
                      "type": "string",
                      "example": ""
                    },
                    "data": {
                      "type": "object",
                      "properties": {
                        "id": {
                          "type": "string",
                          "example": "d4f71d4a-eda4-4237-9976-5cbdc8a54cf3"
                        },
                        "details": {
                          "type": "object",
                          "properties": {
                            "type": {
                              "type": "string",
                              "example": "bank-account"
                            },
                            "accountName": {
                              "type": "string",
                              "example": "Beata Jean"
                            },
                            "accountNumber": {
                              "type": "string",
                              "example": "9130000000000"
                            },
                            "bank": {
                              "type": "object",
                              "properties": {
                                "id": {
                                  "type": "string",
                                  "example": "002"
                                },
                                "name": {
                                  "type": "string",
                                  "example": "Absa Bank"
                                },
                                "country": {
                                  "type": "string",
                                  "example": "zm"
                                }
                              }
                            }
                          }
                        },
                        "currency": {
                          "type": "string",
                          "example": "ZMW"
                        },
                        "type": {
                          "type": "string",
                          "example": "bank-account"
                        },
                        "country": {
                          "type": "string",
                          "example": "zm"
                        }
                      }
                    }
                  }
                }
              }
            }
          },
          "400": {
            "description": "400",
            "content": {
              "application/json": {
                "examples": {
                  "Result": {
                    "value": "{\n    \"status\": false,\n    \"message\": \"Account Details could not be verified\",\n    \"data\": null\n}"
                  }
                },
                "schema": {
                  "type": "object",
                  "properties": {
                    "status": {
                      "type": "boolean",
                      "example": false,
                      "default": true
                    },
                    "message": {
                      "type": "string",
                      "example": "Account Details could not be verified"
                    },
                    "data": {}
                  }
                }
              }
            }
          }
        },
        "deprecated": false
      }
    }
  },
  "x-readme": {
    "headers": [],
    "explorer-enabled": false,
    "proxy-enabled": true
  },
  "x-readme-fauxas": true,
  "_id": "65f06b6583c5de0051b8aa08:65f06b6583c5de0051b8aa12"
}
```

/transfer-recipients/lenco-money

# /transfer-recipients/lenco-money

Create transfer recipient as a bank account

Response schema:

```json
{
    "status": boolean,
    "message": string,
    "data": {
        "id": string,
        "currency": string,
        "type": "string",
        "country": string,
        "details": {
            "type": "lenco-money",
            "accountName": string,
            "walletNumber": string
        }
    }
}
```

# OpenAPI definition

```json
{
  "openapi": "3.1.0",
  "info": {
    "title": "Lenco API",
    "version": "2.0"
  },
  "servers": [
    {
      "url": "https://api.lenco.co/access/v2"
    }
  ],
  "components": {
    "securitySchemes": {
      "sec0": {
        "type": "apiKey",
        "in": "header",
        "name": "Authorization",
        "x-bearer-format": "bearer",
        "x-default": "xo+CAiijrIy9XvZCYyhjrv0fpSAL6CfU8CgA+up1NXqK"
      }
    }
  },
  "security": [
    {
      "sec0": []
    }
  ],
  "paths": {
    "/transfer-recipients/lenco-money": {
      "post": {
        "summary": "/transfer-recipients/lenco-money",
        "description": "Create transfer recipient as a bank account",
        "operationId": "create-transfer-recipient-as-lenco-money",
        "requestBody": {
          "content": {
            "application/json": {
              "schema": {
                "type": "object",
                "required": [
                  "walletNumber"
                ],
                "properties": {
                  "walletNumber": {
                    "type": "string"
                  }
                }
              }
            }
          }
        },
        "responses": {
          "200": {
            "description": "200",
            "content": {
              "application/json": {
                "examples": {
                  "Result": {
                    "value": "{\n    \"status\": true,\n    \"message\": \"\",\n    \"data\": {\n        \"id\": \"d4f71d4a-eda4-4237-9976-5cbdc8a54cf3\",\n        \"details\": {\n            \"type\": \"lenco-money\",\n            \"accountName\": \"Beata Jean\",\n            \"walletNumber\": \"0000001\",\n        },\n        \"currency\": \"ZMW\",\n        \"type\": \"lenco-money\",\n        \"country\": \"zm\"\n    }\n}"
                  }
                }
              }
            }
          },
          "400": {
            "description": "400",
            "content": {
              "application/json": {
                "examples": {
                  "Result": {
                    "value": "{\n    \"status\": false,\n    \"message\": \"Account Details could not be verified\",\n    \"data\": null\n}"
                  }
                },
                "schema": {
                  "type": "object",
                  "properties": {
                    "status": {
                      "type": "boolean",
                      "example": false,
                      "default": true
                    },
                    "message": {
                      "type": "string",
                      "example": "Account Details could not be verified"
                    },
                    "data": {}
                  }
                }
              }
            }
          }
        },
        "deprecated": false
      }
    }
  },
  "x-readme": {
    "headers": [],
    "explorer-enabled": false,
    "proxy-enabled": true
  },
  "x-readme-fauxas": true,
  "_id": "65f06b6583c5de0051b8aa08:65f17927342f24003acc1fbb"
}
```

/transfer-recipients/lenco-merchant

# /transfer-recipients/lenco-merchant

Create transfer recipient as a bank account

Response schema:

```json
{
    "status": boolean,
    "message": string,
    "data": {
        "id": string,
        "currency": string,
        "type": "string",
        "country": string,
        "details": {
            "type": "lenco-merchant",
            "accountName": string,
            "tillNumber": string
        }
    }
}
```

# OpenAPI definition

```json
{
  "openapi": "3.1.0",
  "info": {
    "title": "Lenco API",
    "version": "2.0"
  },
  "servers": [
    {
      "url": "https://api.lenco.co/access/v2"
    }
  ],
  "components": {
    "securitySchemes": {
      "sec0": {
        "type": "apiKey",
        "in": "header",
        "name": "Authorization",
        "x-bearer-format": "bearer",
        "x-default": "xo+CAiijrIy9XvZCYyhjrv0fpSAL6CfU8CgA+up1NXqK"
      }
    }
  },
  "security": [
    {
      "sec0": []
    }
  ],
  "paths": {
    "/transfer-recipients/lenco-merchant": {
      "post": {
        "summary": "/transfer-recipients/lenco-merchant",
        "description": "Create transfer recipient as a bank account",
        "operationId": "create-transfer-recipient-as-lenco-merchant",
        "requestBody": {
          "content": {
            "application/json": {
              "schema": {
                "type": "object",
                "required": [
                  "tillNumber"
                ],
                "properties": {
                  "tillNumber": {
                    "type": "string"
                  }
                }
              }
            }
          }
        },
        "responses": {
          "200": {
            "description": "200",
            "content": {
              "application/json": {
                "examples": {
                  "Result": {
                    "value": "{\n    \"status\": true,\n    \"message\": \"\",\n    \"data\": {\n        \"id\": \"d4f71d4a-eda4-4237-9976-5cbdc8a54cf3\",\n        \"details\": {\n            \"type\": \"lenco-merchant\",\n            \"accountName\": \"Account Name\",\n            \"tillNumber\": \"0000001\",\n        },\n        \"currency\": \"ZMW\",\n        \"type\": \"lenco-merchant\",\n        \"country\": \"zm\"\n    }\n}"
                  }
                }
              }
            }
          },
          "400": {
            "description": "400",
            "content": {
              "application/json": {
                "examples": {
                  "Result": {
                    "value": "{\n    \"status\": false,\n    \"message\": \"Account Details could not be verified\",\n    \"data\": null\n}"
                  }
                },
                "schema": {
                  "type": "object",
                  "properties": {
                    "status": {
                      "type": "boolean",
                      "example": false,
                      "default": true
                    },
                    "message": {
                      "type": "string",
                      "example": "Account Details could not be verified"
                    },
                    "data": {}
                  }
                }
              }
            }
          }
        },
        "deprecated": false
      }
    }
  },
  "x-readme": {
    "headers": [],
    "explorer-enabled": false,
    "proxy-enabled": true
  },
  "x-readme-fauxas": true,
  "_id": "65f06b6583c5de0051b8aa08:65f17929b650d0003440d860"
}
```

/transfers

# /transfers

Retrieve information about your transfers

Response Schema:

```json
{
    "status": boolean,
    "message": string,
    "data": [
        {
            "id": string,
            "amount": string,
            "fee": string,
            "currency": string,
            "narration": string,
            "initiatedAt": date-time,
            "completedAt": date-time | null,
            "accountId": string,
            "creditAccount": {
                "id": string | null,
                "type": string,
                "accountName": string,
                "accountNumber": string | null,
                "bank": {
                    "id": string,
                    "name": string,
                    "country": string
                } | null,
                "phone": string | null,
                "operator": string | null,
                "walletNumber": string | null,
                "tillNumber": string | null
            },
            "status": "pending" | "successful" | "failed",
            "reasonForFailure": string | null,
            "reference": string | null,
            "lencoReference": string,
            "extraData": {
                "nipSessionId": string | null,
            },
            "source": "banking-app" | "api"
        }
    ],
    "meta": {
        "total": number,
        "pageCount": number,
        "perPage": number,
        "currentPage": number
    }
}
```

# OpenAPI definition

```json
{
  "openapi": "3.1.0",
  "info": {
    "title": "Lenco API",
    "version": "2.0"
  },
  "servers": [
    {
      "url": "https://api.lenco.co/access/v2"
    }
  ],
  "components": {
    "securitySchemes": {
      "sec0": {
        "type": "apiKey",
        "in": "header",
        "name": "Authorization",
        "x-bearer-format": "bearer",
        "x-default": "xo+CAiijrIy9XvZCYyhjrv0fpSAL6CfU8CgA+up1NXqK"
      }
    }
  },
  "security": [
    {
      "sec0": []
    }
  ],
  "paths": {
    "/transfers": {
      "get": {
        "summary": "/transfers",
        "description": "Retrieve information about your transfers",
        "operationId": "get-transfers",
        "parameters": [
          {
            "name": "page",
            "in": "query",
            "description": "If not specified, it defaults to 1",
            "schema": {
              "type": "integer",
              "format": "int32",
              "default": 1
            }
          },
          {
            "name": "from",
            "in": "query",
            "description": "Format: YYYY-MM-DD",
            "schema": {
              "type": "string",
              "format": "date"
            }
          },
          {
            "name": "to",
            "in": "query",
            "description": "Format: YYYY-MM-DD",
            "schema": {
              "type": "string",
              "format": "date"
            }
          },
          {
            "name": "search",
            "in": "query",
            "description": "Search term to look for",
            "schema": {
              "type": "string"
            }
          },
          {
            "name": "accountId",
            "in": "query",
            "description": "Your 36-character account uuid to filter transfers",
            "schema": {
              "type": "string"
            }
          },
          {
            "name": "transferRecipientId",
            "in": "query",
            "description": "Your 36-character transfer recipient uuid to filter transfers",
            "schema": {
              "type": "string"
            }
          },
          {
            "name": "type",
            "in": "query",
            "description": "either `mobile-money`, `bank-account`, `lenco-money`, or `lenco-merchant`",
            "schema": {
              "type": "string"
            }
          },
          {
            "name": "status",
            "in": "query",
            "description": "either `pending`, `successful`, or `failed`",
            "schema": {
              "type": "string"
            }
          },
          {
            "name": "country",
            "in": "query",
            "description": "i.e. `ng`, `zm`",
            "schema": {
              "type": "string"
            }
          }
        ],
        "responses": {
          "200": {
            "description": "200",
            "content": {
              "application/json": {
                "examples": {
                  "Result": {
                    "value": "{\n    \"status\": true,\n    \"message\": \"\",\n    \"data\": [\n        {\n            \"id\": \"9525b4c6-502b-45be-90e1-81eb81a3f424\",\n            \"amount\": \"20.00\",\n            \"fee\": \"8.50\",\n            \"currency\": \"ZMW\",\n            \"narration\": \"Transfer\",\n            \"initiatedAt\": \"2024-01-01T00:00:00.447Z\",\n            \"completedAt\": \"2024-01-01T00:00:01.237Z\",\n            \"accountId\": \"b176cda5-7d97-4a3f-b4dd-ab0234e9e08c\",\n            \"creditAccount\": {\n                \"type\": \"bank-account\",\n                \"accountName\": \"Beata Jean\",\n                \"accountNumber\": \"9130000000000\",\n                \"bank\": {\n                    \"id\": \"002\",\n                    \"name\": \"Absa Bank\",\n                    \"country\": \"zm\"\n                }\n            },\n            \"status\": \"successful\",\n            \"reasonForFailure\": null,\n            \"reference\": \"ref-3\",\n            \"lencoReference\": \"240010002\",\n            \"extraData\": {\n                \"nipSessionId\": null\n            },\n            \"source\": \"api\"\n        }\n    ],\n    \"meta\": {\n        \"total\": 1,\n        \"pageCount\": 1,\n        \"perPage\": 100,\n        \"currentPage\": 1\n    }\n}"
                  }
                },
                "schema": {
                  "type": "object",
                  "properties": {
                    "status": {
                      "type": "boolean",
                      "example": true,
                      "default": true
                    },
                    "message": {
                      "type": "string",
                      "example": ""
                    },
                    "data": {
                      "type": "array",
                      "items": {
                        "type": "object",
                        "properties": {
                          "id": {
                            "type": "string",
                            "example": "9525b4c6-502b-45be-90e1-81eb81a3f424"
                          },
                          "amount": {
                            "type": "string",
                            "example": "20.00"
                          },
                          "fee": {
                            "type": "string",
                            "example": "8.50"
                          },
                          "currency": {
                            "type": "string",
                            "example": "ZMW"
                          },
                          "narration": {
                            "type": "string",
                            "example": "Transfer"
                          },
                          "initiatedAt": {
                            "type": "string",
                            "example": "2024-01-01T00:00:00.447Z"
                          },
                          "completedAt": {
                            "type": "string",
                            "example": "2024-01-01T00:00:01.237Z"
                          },
                          "accountId": {
                            "type": "string",
                            "example": "b176cda5-7d97-4a3f-b4dd-ab0234e9e08c"
                          },
                          "creditAccount": {
                            "type": "object",
                            "properties": {
                              "type": {
                                "type": "string",
                                "example": "bank-account"
                              },
                              "accountName": {
                                "type": "string",
                                "example": "Beata Jean"
                              },
                              "accountNumber": {
                                "type": "string",
                                "example": "9130000000000"
                              },
                              "bank": {
                                "type": "object",
                                "properties": {
                                  "id": {
                                    "type": "string",
                                    "example": "002"
                                  },
                                  "name": {
                                    "type": "string",
                                    "example": "Absa Bank"
                                  },
                                  "country": {
                                    "type": "string",
                                    "example": "zm"
                                  }
                                }
                              }
                            }
                          },
                          "status": {
                            "type": "string",
                            "example": "successful"
                          },
                          "reasonForFailure": {},
                          "reference": {
                            "type": "string",
                            "example": "ref-3"
                          },
                          "lencoReference": {
                            "type": "string",
                            "example": "240010002"
                          },
                          "extraData": {
                            "type": "object",
                            "properties": {
                              "nipSessionId": {}
                            }
                          },
                          "source": {
                            "type": "string",
                            "example": "api"
                          }
                        }
                      }
                    },
                    "meta": {
                      "type": "object",
                      "properties": {
                        "total": {
                          "type": "integer",
                          "example": 1,
                          "default": 0
                        },
                        "pageCount": {
                          "type": "integer",
                          "example": 1,
                          "default": 0
                        },
                        "perPage": {
                          "type": "integer",
                          "example": 100,
                          "default": 0
                        },
                        "currentPage": {
                          "type": "integer",
                          "example": 1,
                          "default": 0
                        }
                      }
                    }
                  }
                }
              }
            }
          }
        },
        "deprecated": false
      }
    }
  },
  "x-readme": {
    "headers": [],
    "explorer-enabled": false,
    "proxy-enabled": true
  },
  "x-readme-fauxas": true,
  "_id": "65f06b6583c5de0051b8aa08:65f19b5d8309b5006767dadb"
}
```

/transfers/:id

# /transfers/:id

Retrieve information about a specific transfer

Response Schema:

```json
{
    "status": boolean,
    "message": string,
    "data": {
        "id": string,
        "amount": string,
        "fee": string,
        "currency": string,
        "narration": string,
        "initiatedAt": date-time,
        "completedAt": date-time | null,
        "accountId": string,
        "creditAccount": {
            "id": string | null,
            "type": string,
            "accountName": string,
            "accountNumber": string | null,
            "bank": {
                "id": string,
                "name": string,
                "country": string
            } | null,
            "phone": string | null,
            "operator": string | null,
            "walletNumber": string | null,
            "tillNumber": string | null
        },
        "status": "pending" | "successful" | "failed",
        "reasonForFailure": string | null,
        "reference": string | null,
        "lencoReference": string,
        "extraData": {
            "nipSessionId": string | null,
        },
        "source": string
    }
}
```

# OpenAPI definition

```json
{
  "openapi": "3.1.0",
  "info": {
    "title": "Lenco API",
    "version": "2.0"
  },
  "servers": [
    {
      "url": "https://api.lenco.co/access/v2"
    }
  ],
  "components": {
    "securitySchemes": {
      "sec0": {
        "type": "apiKey",
        "in": "header",
        "name": "Authorization",
        "x-bearer-format": "bearer",
        "x-default": "xo+CAiijrIy9XvZCYyhjrv0fpSAL6CfU8CgA+up1NXqK"
      }
    }
  },
  "security": [
    {
      "sec0": []
    }
  ],
  "paths": {
    "/transfers/{id}": {
      "get": {
        "summary": "/transfers/:id",
        "description": "Retrieve information about a specific transfer",
        "operationId": "get-transfer-by-id",
        "parameters": [
          {
            "name": "id",
            "in": "path",
            "description": "Your 36-character transfer uuid",
            "schema": {
              "type": "string"
            },
            "required": true
          }
        ],
        "responses": {
          "200": {
            "description": "200",
            "content": {
              "application/json": {
                "examples": {
                  "Result": {
                    "value": "{\n    \"status\": true,\n    \"message\": \"\",\n    \"data\": {\n        \"id\": \"9525b4c6-502b-45be-90e1-81eb81a3f424\",\n        \"amount\": \"20.00\",\n        \"fee\": \"8.50\",\n        \"currency\": \"ZMW\",\n        \"narration\": \"Transfer\",\n        \"initiatedAt\": \"2024-01-01T00:00:00.447Z\",\n        \"completedAt\": \"2024-01-01T00:00:01.237Z\",\n        \"accountId\": \"b176cda5-7d97-4a3f-b4dd-ab0234e9e08c\",\n        \"creditAccount\": {\n            \"type\": \"bank-account\",\n            \"accountName\": \"Beata Jean\",\n            \"accountNumber\": \"9130000000000\",\n            \"bank\": {\n                \"id\": \"002\",\n                \"name\": \"Absa Bank\",\n                \"country\": \"zm\"\n            }\n        },\n        \"status\": \"successful\",\n        \"reasonForFailure\": null,\n        \"reference\": \"ref-3\",\n        \"lencoReference\": \"240010002\",\n        \"extraData\": {\n            \"nipSessionId\": null\n        },\n        \"source\": \"api\"\n    }\n}"
                  }
                },
                "schema": {
                  "type": "object",
                  "properties": {
                    "status": {
                      "type": "boolean",
                      "example": true,
                      "default": true
                    },
                    "message": {
                      "type": "string",
                      "example": ""
                    },
                    "data": {
                      "type": "object",
                      "properties": {
                        "id": {
                          "type": "string",
                          "example": "9525b4c6-502b-45be-90e1-81eb81a3f424"
                        },
                        "amount": {
                          "type": "string",
                          "example": "20.00"
                        },
                        "fee": {
                          "type": "string",
                          "example": "8.50"
                        },
                        "currency": {
                          "type": "string",
                          "example": "ZMW"
                        },
                        "narration": {
                          "type": "string",
                          "example": "Transfer"
                        },
                        "initiatedAt": {
                          "type": "string",
                          "example": "2024-01-01T00:00:00.447Z"
                        },
                        "completedAt": {
                          "type": "string",
                          "example": "2024-01-01T00:00:01.237Z"
                        },
                        "accountId": {
                          "type": "string",
                          "example": "b176cda5-7d97-4a3f-b4dd-ab0234e9e08c"
                        },
                        "creditAccount": {
                          "type": "object",
                          "properties": {
                            "type": {
                              "type": "string",
                              "example": "bank-account"
                            },
                            "accountName": {
                              "type": "string",
                              "example": "Beata Jean"
                            },
                            "accountNumber": {
                              "type": "string",
                              "example": "9130000000000"
                            },
                            "bank": {
                              "type": "object",
                              "properties": {
                                "id": {
                                  "type": "string",
                                  "example": "002"
                                },
                                "name": {
                                  "type": "string",
                                  "example": "Absa Bank"
                                },
                                "country": {
                                  "type": "string",
                                  "example": "zm"
                                }
                              }
                            }
                          }
                        },
                        "status": {
                          "type": "string",
                          "example": "successful"
                        },
                        "reasonForFailure": {},
                        "reference": {
                          "type": "string",
                          "example": "ref-3"
                        },
                        "lencoReference": {
                          "type": "string",
                          "example": "240010002"
                        },
                        "extraData": {
                          "type": "object",
                          "properties": {
                            "nipSessionId": {}
                          }
                        },
                        "source": {
                          "type": "string",
                          "example": "api"
                        }
                      }
                    }
                  }
                }
              }
            }
          },
          "404": {
            "description": "404",
            "content": {
              "application/json": {
                "examples": {
                  "Result": {
                    "value": "{\n    \"status\": false,\n    \"message\": \"Transfer was not found\",\n    \"data\": null\n}"
                  }
                },
                "schema": {
                  "type": "object",
                  "properties": {
                    "status": {
                      "type": "boolean",
                      "example": false,
                      "default": true
                    },
                    "message": {
                      "type": "string",
                      "example": "Transfer was not found"
                    },
                    "data": {}
                  }
                }
              }
            }
          }
        },
        "deprecated": false
      }
    }
  },
  "x-readme": {
    "headers": [],
    "explorer-enabled": false,
    "proxy-enabled": true
  },
  "x-readme-fauxas": true,
  "_id": "65f06b6583c5de0051b8aa08:65f19b741f36c700162c605b"
}
```

/transfers/status/:reference

# /transfers/status/:reference

Retrieve information about a specific transfer using the reference you used when initiating the transfer

Response Schema:

```json
{
    "status": boolean,
    "message": string,
    "data": {
        "id": string,
        "amount": string,
        "fee": string,
        "currency": string,
        "narration": string,
        "initiatedAt": date-time,
        "completedAt": date-time | null,
        "accountId": string,
        "creditAccount": {
            "id": string | null,
            "type": string,
            "accountName": string,
            "accountNumber": string | null,
            "bank": {
                "id": string,
                "name": string,
                "country": string
            } | null,
            "phone": string | null,
            "operator": string | null,
            "walletNumber": string | null,
            "tillNumber": string | null
        },
        "status": "pending" | "successful" | "failed",
        "reasonForFailure": string | null,
        "reference": string | null,
        "lencoReference": string,
        "extraData": {
            "nipSessionId": string | null,
        },
        "source": string
    }
}
```

# OpenAPI definition

```json
{
  "openapi": "3.1.0",
  "info": {
    "title": "Lenco API",
    "version": "2.0"
  },
  "servers": [
    {
      "url": "https://api.lenco.co/access/v2"
    }
  ],
  "components": {
    "securitySchemes": {
      "sec0": {
        "type": "apiKey",
        "in": "header",
        "name": "Authorization",
        "x-bearer-format": "bearer",
        "x-default": "xo+CAiijrIy9XvZCYyhjrv0fpSAL6CfU8CgA+up1NXqK"
      }
    }
  },
  "security": [
    {
      "sec0": []
    }
  ],
  "paths": {
    "/transfers/status/{reference}": {
      "get": {
        "summary": "/transfers/status/:reference",
        "description": "Retrieve information about a specific transfer using the reference you used when initiating the transfer",
        "operationId": "get-transfer-by-reference",
        "parameters": [
          {
            "name": "reference",
            "in": "path",
            "description": "The reference used when initiating the transfer",
            "schema": {
              "type": "string"
            },
            "required": true
          }
        ],
        "responses": {
          "200": {
            "description": "200",
            "content": {
              "application/json": {
                "examples": {
                  "Result": {
                    "value": "{\n    \"status\": true,\n    \"message\": \"\",\n    \"data\": {\n        \"id\": \"9525b4c6-502b-45be-90e1-81eb81a3f424\",\n        \"amount\": \"20.00\",\n        \"fee\": \"8.50\",\n        \"currency\": \"ZMW\",\n        \"narration\": \"Transfer\",\n        \"initiatedAt\": \"2024-01-01T00:00:00.447Z\",\n        \"completedAt\": \"2024-01-01T00:00:01.237Z\",\n        \"accountId\": \"b176cda5-7d97-4a3f-b4dd-ab0234e9e08c\",\n        \"creditAccount\": {\n            \"type\": \"bank-account\",\n            \"accountName\": \"Beata Jean\",\n            \"accountNumber\": \"9130000000000\",\n            \"bank\": {\n                \"id\": \"002\",\n                \"name\": \"Absa Bank\",\n                \"country\": \"zm\"\n            }\n        },\n        \"status\": \"successful\",\n        \"reasonForFailure\": null,\n        \"reference\": \"ref-3\",\n        \"lencoReference\": \"240010002\",\n        \"extraData\": {\n            \"nipSessionId\": null\n        },\n        \"source\": \"api\"\n    }\n}"
                  }
                },
                "schema": {
                  "type": "object",
                  "properties": {
                    "status": {
                      "type": "boolean",
                      "example": true,
                      "default": true
                    },
                    "message": {
                      "type": "string",
                      "example": ""
                    },
                    "data": {
                      "type": "object",
                      "properties": {
                        "id": {
                          "type": "string",
                          "example": "9525b4c6-502b-45be-90e1-81eb81a3f424"
                        },
                        "amount": {
                          "type": "string",
                          "example": "20.00"
                        },
                        "fee": {
                          "type": "string",
                          "example": "8.50"
                        },
                        "currency": {
                          "type": "string",
                          "example": "ZMW"
                        },
                        "narration": {
                          "type": "string",
                          "example": "Transfer"
                        },
                        "initiatedAt": {
                          "type": "string",
                          "example": "2024-01-01T00:00:00.447Z"
                        },
                        "completedAt": {
                          "type": "string",
                          "example": "2024-01-01T00:00:01.237Z"
                        },
                        "accountId": {
                          "type": "string",
                          "example": "b176cda5-7d97-4a3f-b4dd-ab0234e9e08c"
                        },
                        "creditAccount": {
                          "type": "object",
                          "properties": {
                            "type": {
                              "type": "string",
                              "example": "bank-account"
                            },
                            "accountName": {
                              "type": "string",
                              "example": "Beata Jean"
                            },
                            "accountNumber": {
                              "type": "string",
                              "example": "9130000000000"
                            },
                            "bank": {
                              "type": "object",
                              "properties": {
                                "id": {
                                  "type": "string",
                                  "example": "002"
                                },
                                "name": {
                                  "type": "string",
                                  "example": "Absa Bank"
                                },
                                "country": {
                                  "type": "string",
                                  "example": "zm"
                                }
                              }
                            }
                          }
                        },
                        "status": {
                          "type": "string",
                          "example": "successful"
                        },
                        "reasonForFailure": {},
                        "reference": {
                          "type": "string",
                          "example": "ref-3"
                        },
                        "lencoReference": {
                          "type": "string",
                          "example": "240010002"
                        },
                        "extraData": {
                          "type": "object",
                          "properties": {
                            "nipSessionId": {}
                          }
                        },
                        "source": {
                          "type": "string",
                          "example": "api"
                        }
                      }
                    }
                  }
                }
              }
            }
          },
          "404": {
            "description": "404",
            "content": {
              "application/json": {
                "examples": {
                  "Result": {
                    "value": "{\n    \"status\": false,\n    \"message\": \"Transfer was not found\",\n    \"data\": null\n}"
                  }
                },
                "schema": {
                  "type": "object",
                  "properties": {
                    "status": {
                      "type": "boolean",
                      "example": false,
                      "default": true
                    },
                    "message": {
                      "type": "string",
                      "example": "Transfer was not found"
                    },
                    "data": {}
                  }
                }
              }
            }
          }
        },
        "deprecated": false
      }
    }
  },
  "x-readme": {
    "headers": [],
    "explorer-enabled": false,
    "proxy-enabled": true
  },
  "x-readme-fauxas": true,
  "_id": "65f06b6583c5de0051b8aa08:65f19bc16f0ae20079796bbc"
}
```

/transfers/bank-account

# /transfers/bank-account

Initiate transfer to a bank account

Response Schema:

```json
{
    "status": boolean,
    "message": string,
    "data": {
        "id": string,
        "amount": string,
        "fee": string,
        "currency": string,
        "narration": string,
        "initiatedAt": date-time,
        "completedAt": date-time | null,
        "accountId": string,
        "creditAccount": {
            "type": "bank-account",
            "accountName": string,
            "accountNumber": string,
            "bank": {
                "id": string,
                "name": string,
                "country": string
            }
        },
        "status": "pending" | "successful" | "failed",
        "reasonForFailure": string | null,
        "reference": string | null,
        "lencoReference": string,
        "extraData": {
            "nipSessionId": string | null,
        },
        "source": string
    }
}
```

# OpenAPI definition

```json
{
  "openapi": "3.1.0",
  "info": {
    "title": "Lenco API",
    "version": "2.0"
  },
  "servers": [
    {
      "url": "https://api.lenco.co/access/v2"
    }
  ],
  "components": {
    "securitySchemes": {
      "sec0": {
        "type": "apiKey",
        "in": "header",
        "name": "Authorization",
        "x-bearer-format": "bearer",
        "x-default": "xo+CAiijrIy9XvZCYyhjrv0fpSAL6CfU8CgA+up1NXqK"
      }
    }
  },
  "security": [
    {
      "sec0": []
    }
  ],
  "paths": {
    "/transfers/bank-account": {
      "post": {
        "summary": "/transfers/bank-account",
        "description": "Initiate transfer to a bank account",
        "operationId": "initiate-transfer-to-bank-account",
        "requestBody": {
          "content": {
            "application/json": {
              "schema": {
                "type": "object",
                "required": [
                  "accountId",
                  "amount",
                  "reference"
                ],
                "properties": {
                  "accountId": {
                    "type": "string",
                    "description": "Your 36-character account uuid to debit"
                  },
                  "amount": {
                    "type": "number",
                    "format": "double"
                  },
                  "narration": {
                    "type": "string",
                    "description": "Optional"
                  },
                  "reference": {
                    "type": "string",
                    "description": "Unique client reference. Only `-`, `.`, `_` and alphanumeric characters allowed"
                  },
                  "transferRecipientId": {
                    "type": "string",
                    "description": "Optional. 36-character transfer recipient uuid"
                  },
                  "accountNumber": {
                    "type": "string",
                    "description": "Optional. If you do not have the transferRecipientId, use this and bankId"
                  },
                  "bankId": {
                    "type": "string",
                    "description": "Optional. If you do not have the transferRecipientId, use this and accountNumber"
                  },
                  "country": {
                    "type": "string",
                    "description": "Optional. i.e. `ng`, `zm`"
                  }
                }
              }
            }
          }
        },
        "responses": {
          "200": {
            "description": "200",
            "content": {
              "application/json": {
                "examples": {
                  "Result": {
                    "value": "{\n    \"status\": true,\n    \"message\": \"\",\n    \"data\": {\n        \"id\": \"9525b4c6-502b-45be-90e1-81eb81a3f424\",\n        \"amount\": \"20.00\",\n        \"fee\": \"8.50\",\n        \"currency\": \"ZMW\",\n        \"narration\": \"Transfer\",\n        \"initiatedAt\": \"2024-01-01T00:00:00.447Z\",\n        \"completedAt\": \"2024-01-01T00:00:01.237Z\",\n        \"accountId\": \"b176cda5-7d97-4a3f-b4dd-ab0234e9e08c\",\n        \"creditAccount\": {\n            \"type\": \"bank-account\",\n            \"accountName\": \"Beata Jean\",\n            \"accountNumber\": \"9130000000000\",\n            \"bank\": {\n                \"id\": \"002\",\n                \"name\": \"Absa Bank\",\n                \"country\": \"zm\"\n            }\n        },\n        \"status\": \"successful\",\n        \"reasonForFailure\": null,\n        \"reference\": \"ref-3\",\n        \"lencoReference\": \"240010002\",\n        \"extraData\": {\n            \"nipSessionId\": null\n        },\n        \"source\": \"api\"\n    }\n}"
                  }
                },
                "schema": {
                  "type": "object",
                  "properties": {
                    "status": {
                      "type": "boolean",
                      "example": true,
                      "default": true
                    },
                    "message": {
                      "type": "string",
                      "example": ""
                    },
                    "data": {
                      "type": "object",
                      "properties": {
                        "id": {
                          "type": "string",
                          "example": "9525b4c6-502b-45be-90e1-81eb81a3f424"
                        },
                        "amount": {
                          "type": "string",
                          "example": "20.00"
                        },
                        "fee": {
                          "type": "string",
                          "example": "8.50"
                        },
                        "currency": {
                          "type": "string",
                          "example": "ZMW"
                        },
                        "narration": {
                          "type": "string",
                          "example": "Transfer"
                        },
                        "initiatedAt": {
                          "type": "string",
                          "example": "2024-01-01T00:00:00.447Z"
                        },
                        "completedAt": {
                          "type": "string",
                          "example": "2024-01-01T00:00:01.237Z"
                        },
                        "accountId": {
                          "type": "string",
                          "example": "b176cda5-7d97-4a3f-b4dd-ab0234e9e08c"
                        },
                        "creditAccount": {
                          "type": "object",
                          "properties": {
                            "type": {
                              "type": "string",
                              "example": "bank-account"
                            },
                            "accountName": {
                              "type": "string",
                              "example": "Beata Jean"
                            },
                            "accountNumber": {
                              "type": "string",
                              "example": "9130000000000"
                            },
                            "bank": {
                              "type": "object",
                              "properties": {
                                "id": {
                                  "type": "string",
                                  "example": "002"
                                },
                                "name": {
                                  "type": "string",
                                  "example": "Absa Bank"
                                },
                                "country": {
                                  "type": "string",
                                  "example": "zm"
                                }
                              }
                            }
                          }
                        },
                        "status": {
                          "type": "string",
                          "example": "successful"
                        },
                        "reasonForFailure": {},
                        "reference": {
                          "type": "string",
                          "example": "ref-3"
                        },
                        "lencoReference": {
                          "type": "string",
                          "example": "240010002"
                        },
                        "extraData": {
                          "type": "object",
                          "properties": {
                            "nipSessionId": {}
                          }
                        },
                        "source": {
                          "type": "string",
                          "example": "api"
                        }
                      }
                    }
                  }
                }
              }
            }
          },
          "400": {
            "description": "400",
            "content": {
              "application/json": {
                "examples": {
                  "Result": {
                    "value": "{\n    \"status\": false,\n    \"message\": \"Duplicate reference\",\n    \"data\": null\n}"
                  }
                },
                "schema": {
                  "type": "object",
                  "properties": {
                    "status": {
                      "type": "boolean",
                      "example": false,
                      "default": true
                    },
                    "message": {
                      "type": "string",
                      "example": "Duplicate reference"
                    },
                    "data": {}
                  }
                }
              }
            }
          }
        },
        "deprecated": false
      }
    }
  },
  "x-readme": {
    "headers": [],
    "explorer-enabled": false,
    "proxy-enabled": true
  },
  "x-readme-fauxas": true,
  "_id": "65f06b6583c5de0051b8aa08:65f19be77bee5a00696b9fb2"
}
```

/transfers/mobile-money

# /transfers/mobile-money

Initiate transfer to a mobile money account. Currently supporting only Malawi and Zambia

Response Schema:

```json
{
    "status": boolean,
    "message": string,
    "data": {
        "id": string,
        "amount": string,
        "fee": string,
        "currency": string,
        "narration": string,
        "initiatedAt": date-time,
        "completedAt": date-time | null,
        "accountId": string,
        "creditAccount": {
            "type": "mobile-money",
            "accountName": string,
            "phone": string,
            "operator": string,
            "country": string
        },
        "status": "pending" | "successful" | "failed",
        "reasonForFailure": string | null,
        "reference": string | null,
        "lencoReference": string,
        "extraData": {
            "nipSessionId": string | null,
        },
        "source": string
    }
}
```

# OpenAPI definition

```json
{
  "openapi": "3.1.0",
  "info": {
    "title": "Lenco API",
    "version": "2.0"
  },
  "servers": [
    {
      "url": "https://api.lenco.co/access/v2"
    }
  ],
  "components": {
    "securitySchemes": {
      "sec0": {
        "type": "apiKey",
        "in": "header",
        "name": "Authorization",
        "x-bearer-format": "bearer",
        "x-default": "xo+CAiijrIy9XvZCYyhjrv0fpSAL6CfU8CgA+up1NXqK"
      }
    }
  },
  "security": [
    {
      "sec0": []
    }
  ],
  "paths": {
    "/transfers/mobile-money": {
      "post": {
        "summary": "/transfers/mobile-money",
        "description": "Initiate transfer to a mobile money account. Currently supporting only Malawi and Zambia",
        "operationId": "initiate-transfer-to-mobile-money",
        "requestBody": {
          "content": {
            "application/json": {
              "schema": {
                "type": "object",
                "required": [
                  "accountId",
                  "amount",
                  "reference"
                ],
                "properties": {
                  "accountId": {
                    "type": "string",
                    "description": "Your 36-character account uuid to debit"
                  },
                  "amount": {
                    "type": "number",
                    "format": "double"
                  },
                  "narration": {
                    "type": "string",
                    "description": "Optional"
                  },
                  "reference": {
                    "type": "string",
                    "description": "Unique client reference. Only `-`, `.`, `_` and alphanumeric characters allowed"
                  },
                  "transferRecipientId": {
                    "type": "string",
                    "description": "Optional. 36-character transfer recipient uuid"
                  },
                  "phone": {
                    "type": "string",
                    "description": "Optional. If you do not have the transferRecipientId, use this and operator"
                  },
                  "operator": {
                    "type": "string",
                    "description": "Optional. If you do not have the transferRecipientId, use this and phone. <br>For Zambia, either `airtel`, `mtn`or `zamtel` <br>For Malawi, either `airtel`, or `tnm`",
                    "enum": [
                      "airtel",
                      "mtn",
                      "tnm",
                      "zamtel"
                    ]
                  },
                  "country": {
                    "type": "string",
                    "description": "Optional. Either `zm` (Zambia), or `mw` (Malawi)"
                  }
                }
              }
            }
          }
        },
        "responses": {
          "200": {
            "description": "200",
            "content": {
              "application/json": {
                "examples": {
                  "Result": {
                    "value": "{\n    \"status\": true,\n    \"message\": \"\",\n    \"data\": {\n        \"id\": \"9525b4c6-502b-45be-90e1-81eb81a3f424\",\n        \"amount\": \"20.00\",\n        \"fee\": \"8.50\",\n        \"currency\": \"ZMW\",\n        \"narration\": \"Transfer\",\n        \"initiatedAt\": \"2024-01-01T00:00:00.447Z\",\n        \"completedAt\": \"2024-01-01T00:00:01.237Z\",\n        \"accountId\": \"b176cda5-7d97-4a3f-b4dd-ab0234e9e08c\",\n        \"creditAccount\": {\n            \"type\": \"mobile-money\",\n            \"accountName\": \"Beata Jean\",\n            \"phone\": \"0750000000\",\n            \"operator\": \"zamtel\",\n            \"operator\": \"zm\"\n        },\n        \"status\": \"successful\",\n        \"reasonForFailure\": null,\n        \"reference\": \"ref-3\",\n        \"lencoReference\": \"240010002\",\n        \"extraData\": {\n            \"nipSessionId\": null\n        },\n        \"source\": \"api\"\n    }\n}"
                  }
                },
                "schema": {
                  "type": "object",
                  "properties": {
                    "status": {
                      "type": "boolean",
                      "example": true,
                      "default": true
                    },
                    "message": {
                      "type": "string",
                      "example": ""
                    },
                    "data": {
                      "type": "object",
                      "properties": {
                        "id": {
                          "type": "string",
                          "example": "9525b4c6-502b-45be-90e1-81eb81a3f424"
                        },
                        "amount": {
                          "type": "string",
                          "example": "20.00"
                        },
                        "fee": {
                          "type": "string",
                          "example": "8.50"
                        },
                        "currency": {
                          "type": "string",
                          "example": "ZMW"
                        },
                        "narration": {
                          "type": "string",
                          "example": "Transfer"
                        },
                        "initiatedAt": {
                          "type": "string",
                          "example": "2024-01-01T00:00:00.447Z"
                        },
                        "completedAt": {
                          "type": "string",
                          "example": "2024-01-01T00:00:01.237Z"
                        },
                        "accountId": {
                          "type": "string",
                          "example": "b176cda5-7d97-4a3f-b4dd-ab0234e9e08c"
                        },
                        "creditAccount": {
                          "type": "object",
                          "properties": {
                            "type": {
                              "type": "string",
                              "example": "mobile-money"
                            },
                            "accountName": {
                              "type": "string",
                              "example": "Beata Jean"
                            },
                            "phone": {
                              "type": "string",
                              "example": "0750000000"
                            },
                            "operator": {
                              "type": "string",
                              "example": "zm"
                            }
                          }
                        },
                        "status": {
                          "type": "string",
                          "example": "successful"
                        },
                        "reasonForFailure": {},
                        "reference": {
                          "type": "string",
                          "example": "ref-3"
                        },
                        "lencoReference": {
                          "type": "string",
                          "example": "240010002"
                        },
                        "extraData": {
                          "type": "object",
                          "properties": {
                            "nipSessionId": {}
                          }
                        },
                        "source": {
                          "type": "string",
                          "example": "api"
                        }
                      }
                    }
                  }
                }
              }
            }
          },
          "400": {
            "description": "400",
            "content": {
              "application/json": {
                "examples": {
                  "Result": {
                    "value": "{\n    \"status\": false,\n    \"message\": \"Duplicate reference\",\n    \"data\": null\n}"
                  }
                },
                "schema": {
                  "type": "object",
                  "properties": {
                    "status": {
                      "type": "boolean",
                      "example": false,
                      "default": true
                    },
                    "message": {
                      "type": "string",
                      "example": "Duplicate reference"
                    },
                    "data": {}
                  }
                }
              }
            }
          }
        },
        "deprecated": false
      }
    }
  },
  "x-readme": {
    "headers": [],
    "explorer-enabled": false,
    "proxy-enabled": true
  },
  "x-readme-fauxas": true,
  "_id": "65f06b6583c5de0051b8aa08:65f19bf3e052180025621b0b"
}
```

/transfers/lenco-money

# /transfers/lenco-money

Response Schema:

```json
{
    "status": boolean,
    "message": string,
    "data": {
        "id": string,
        "amount": string,
        "fee": string,
        "currency": string,
        "narration": string,
        "initiatedAt": date-time,
        "completedAt": date-time | null,
        "accountId": string,
        "creditAccount": {
            "type": "lenco-money",
            "accountName": string,
            "walletNumber": string
        },
        "status": "pending" | "successful" | "failed",
        "reasonForFailure": string | null,
        "reference": string | null,
        "lencoReference": string,
        "extraData": {
            "nipSessionId": string | null,
        },
        "source": string
    }
}
```

# OpenAPI definition

```json
{
  "openapi": "3.1.0",
  "info": {
    "title": "Lenco API",
    "version": "2.0"
  },
  "servers": [
    {
      "url": "https://api.lenco.co/access/v2"
    }
  ],
  "components": {
    "securitySchemes": {
      "sec0": {
        "type": "apiKey",
        "in": "header",
        "name": "Authorization",
        "x-bearer-format": "bearer",
        "x-default": "xo+CAiijrIy9XvZCYyhjrv0fpSAL6CfU8CgA+up1NXqK"
      }
    }
  },
  "security": [
    {
      "sec0": []
    }
  ],
  "paths": {
    "/transfers/lenco-money": {
      "post": {
        "summary": "/transfers/lenco-money",
        "description": "",
        "operationId": "initiate-transfer-to-lenco-money",
        "requestBody": {
          "content": {
            "application/json": {
              "schema": {
                "type": "object",
                "required": [
                  "accountId",
                  "amount",
                  "reference"
                ],
                "properties": {
                  "accountId": {
                    "type": "string",
                    "description": "Your 36-character account uuid to debit"
                  },
                  "amount": {
                    "type": "number",
                    "format": "double"
                  },
                  "narration": {
                    "type": "string",
                    "description": "Optional"
                  },
                  "reference": {
                    "type": "string",
                    "description": "Unique client reference. Only `-`, `.`, `_` and alphanumeric characters allowed"
                  },
                  "transferRecipientId": {
                    "type": "string",
                    "description": "Optional. 36-character transfer recipient uuid"
                  },
                  "walletNumber": {
                    "type": "string",
                    "description": "Optional. If you do not have the transferRecipientId, use this"
                  }
                }
              }
            }
          }
        },
        "responses": {
          "200": {
            "description": "200",
            "content": {
              "application/json": {
                "examples": {
                  "Result": {
                    "value": "{\n    \"status\": true,\n    \"message\": \"\",\n    \"data\": {\n        \"id\": \"9525b4c6-502b-45be-90e1-81eb81a3f424\",\n        \"amount\": \"20.00\",\n        \"fee\": \"8.50\",\n        \"currency\": \"ZMW\",\n        \"narration\": \"Transfer\",\n        \"initiatedAt\": \"2024-01-01T00:00:00.447Z\",\n        \"completedAt\": \"2024-01-01T00:00:01.237Z\",\n        \"accountId\": \"b176cda5-7d97-4a3f-b4dd-ab0234e9e08c\",\n        \"creditAccount\": {\n            \"type\": \"lenco-money\",\n            \"accountName\": \"Beata Jean\",\n            \"walletNumber\": \"0000001\",\n        },\n        \"status\": \"successful\",\n        \"reasonForFailure\": null,\n        \"reference\": \"ref-3\",\n        \"lencoReference\": \"240010002\",\n        \"extraData\": {\n            \"nipSessionId\": null\n        },\n        \"source\": \"api\"\n    }\n}"
                  }
                }
              }
            }
          },
          "400": {
            "description": "400",
            "content": {
              "application/json": {
                "examples": {
                  "Result": {
                    "value": "{\n    \"status\": false,\n    \"message\": \"Duplicate reference\",\n    \"data\": null\n}"
                  }
                },
                "schema": {
                  "type": "object",
                  "properties": {
                    "status": {
                      "type": "boolean",
                      "example": false,
                      "default": true
                    },
                    "message": {
                      "type": "string",
                      "example": "Duplicate reference"
                    },
                    "data": {}
                  }
                }
              }
            }
          }
        },
        "deprecated": false
      }
    }
  },
  "x-readme": {
    "headers": [],
    "explorer-enabled": false,
    "proxy-enabled": true
  },
  "x-readme-fauxas": true,
  "_id": "65f06b6583c5de0051b8aa08:65f19c09506ae30010086f8b"
}
```

/transfers/lenco-merchant

# /transfers/lenco-merchant

Response Schema:

```json
{
    "status": boolean,
    "message": string,
    "data": {
        "id": string,
        "amount": string,
        "fee": string,
        "currency": string,
        "narration": string,
        "initiatedAt": date-time,
        "completedAt": date-time | null,
        "accountId": string,
        "creditAccount": {
            "type": "lenco-merchant",
            "accountName": string,
            "tillNumber": string
        },
        "status": "pending" | "successful" | "failed",
        "reasonForFailure": string | null,
        "reference": string | null,
        "lencoReference": string,
        "extraData": {
            "nipSessionId": string | null,
        },
        "source": string
    }
}
```

# OpenAPI definition

```json
{
  "openapi": "3.1.0",
  "info": {
    "title": "Lenco API",
    "version": "2.0"
  },
  "servers": [
    {
      "url": "https://api.lenco.co/access/v2"
    }
  ],
  "components": {
    "securitySchemes": {
      "sec0": {
        "type": "apiKey",
        "in": "header",
        "name": "Authorization",
        "x-bearer-format": "bearer",
        "x-default": "xo+CAiijrIy9XvZCYyhjrv0fpSAL6CfU8CgA+up1NXqK"
      }
    }
  },
  "security": [
    {
      "sec0": []
    }
  ],
  "paths": {
    "/transfers/lenco-merchant": {
      "post": {
        "summary": "/transfers/lenco-merchant",
        "description": "",
        "operationId": "initiate-transfer-to-lenco-merchant",
        "requestBody": {
          "content": {
            "application/json": {
              "schema": {
                "type": "object",
                "required": [
                  "accountId",
                  "amount",
                  "reference"
                ],
                "properties": {
                  "accountId": {
                    "type": "string",
                    "description": "Your 36-character account uuid to debit"
                  },
                  "amount": {
                    "type": "number",
                    "format": "double"
                  },
                  "narration": {
                    "type": "string",
                    "description": "Optional"
                  },
                  "reference": {
                    "type": "string",
                    "description": "Unique client reference. Only `-`, `.`, `_` and alphanumeric characters allowed"
                  },
                  "transferRecipientId": {
                    "type": "string",
                    "description": "Optional. 36-character transfer recipient uuid"
                  },
                  "tillNumber": {
                    "type": "string",
                    "description": "Optional. If you do not have the transferRecipientId, use this"
                  }
                }
              }
            }
          }
        },
        "responses": {
          "200": {
            "description": "200",
            "content": {
              "application/json": {
                "examples": {
                  "Result": {
                    "value": "{\n    \"status\": true,\n    \"message\": \"\",\n    \"data\": {\n        \"id\": \"9525b4c6-502b-45be-90e1-81eb81a3f424\",\n        \"amount\": \"20.00\",\n        \"fee\": \"8.50\",\n        \"currency\": \"ZMW\",\n        \"narration\": \"Transfer\",\n        \"initiatedAt\": \"2024-01-01T00:00:00.447Z\",\n        \"completedAt\": \"2024-01-01T00:00:01.237Z\",\n        \"accountId\": \"b176cda5-7d97-4a3f-b4dd-ab0234e9e08c\",\n        \"creditAccount\": {\n            \"type\": \"lenco-merchant\",\n            \"accountName\": \"Account Name\",\n            \"tillNumber\": \"0000001\",\n        },\n        \"status\": \"successful\",\n        \"reasonForFailure\": null,\n        \"reference\": \"ref-3\",\n        \"lencoReference\": \"240010002\",\n        \"extraData\": {\n            \"nipSessionId\": null\n        },\n        \"source\": \"api\"\n    }\n}"
                  }
                }
              }
            }
          },
          "400": {
            "description": "400",
            "content": {
              "application/json": {
                "examples": {
                  "Result": {
                    "value": "{\n    \"status\": false,\n    \"message\": \"Duplicate reference\",\n    \"data\": null\n}"
                  }
                },
                "schema": {
                  "type": "object",
                  "properties": {
                    "status": {
                      "type": "boolean",
                      "example": false,
                      "default": true
                    },
                    "message": {
                      "type": "string",
                      "example": "Duplicate reference"
                    },
                    "data": {}
                  }
                }
              }
            }
          }
        },
        "deprecated": false
      }
    }
  },
  "x-readme": {
    "headers": [],
    "explorer-enabled": false,
    "proxy-enabled": true
  },
  "x-readme-fauxas": true,
  "_id": "65f06b6583c5de0051b8aa08:65f19c1cdc532b000f6c8f0c"
}
```

/transfers/account

# /transfers/account

Initiate a transfer to one of your accounts

Response Schema:

```json
{
    "status": boolean,
    "message": string,
    "data": {
        "id": string,
        "amount": string,
        "fee": string,
        "currency": string,
        "narration": string,
        "initiatedAt": date-time,
        "completedAt": date-time | null,
        "accountId": string,
        "creditAccount": {
            "id": string,
            "type": "lenco-merchant",
            "accountName": string,
            "tillNumber": string
        },
        "status": "pending" | "successful" | "failed",
        "reasonForFailure": string | null,
        "reference": string | null,
        "lencoReference": string,
        "extraData": {
            "nipSessionId": string | null,
        },
        "source": string
    }
}
```

# OpenAPI definition

```json
{
  "openapi": "3.1.0",
  "info": {
    "title": "Lenco API",
    "version": "2.0"
  },
  "servers": [
    {
      "url": "https://api.lenco.co/access/v2"
    }
  ],
  "components": {
    "securitySchemes": {
      "sec0": {
        "type": "apiKey",
        "in": "header",
        "name": "Authorization",
        "x-bearer-format": "bearer",
        "x-default": "xo+CAiijrIy9XvZCYyhjrv0fpSAL6CfU8CgA+up1NXqK"
      }
    }
  },
  "security": [
    {
      "sec0": []
    }
  ],
  "paths": {
    "/transfers/account": {
      "post": {
        "summary": "/transfers/account",
        "description": "Initiate a transfer to one of your accounts",
        "operationId": "initiate-transfer-to-account",
        "requestBody": {
          "content": {
            "application/json": {
              "schema": {
                "type": "object",
                "required": [
                  "accountId",
                  "amount",
                  "reference",
                  "creditAccountId"
                ],
                "properties": {
                  "accountId": {
                    "type": "string",
                    "description": "Your 36-character account uuid to debit"
                  },
                  "amount": {
                    "type": "number",
                    "format": "double"
                  },
                  "narration": {
                    "type": "string",
                    "description": "Optional"
                  },
                  "reference": {
                    "type": "string",
                    "description": "Unique client reference. Only `-`, `.`, `_` and alphanumeric characters allowed"
                  },
                  "creditAccountId": {
                    "type": "string",
                    "description": "36-character account uuid to credit"
                  }
                }
              }
            }
          }
        },
        "responses": {
          "200": {
            "description": "200",
            "content": {
              "application/json": {
                "examples": {
                  "Result": {
                    "value": "{\n    \"status\": true,\n    \"message\": \"\",\n    \"data\": {\n        \"id\": \"9525b4c6-502b-45be-90e1-81eb81a3f424\",\n        \"amount\": \"20.00\",\n        \"fee\": \"8.50\",\n        \"currency\": \"ZMW\",\n        \"narration\": \"Transfer\",\n        \"initiatedAt\": \"2024-01-01T00:00:00.447Z\",\n        \"completedAt\": \"2024-01-01T00:00:01.237Z\",\n        \"accountId\": \"b176cda5-7d97-4a3f-b4dd-ab0234e9e08c\",\n        \"creditAccount\": {\n            \"id\": \"a43793f8-7c8d-4062-ab76-4f06ccf3fc34\",\n            \"type\": \"lenco-merchant\",\n            \"accountName\": \"Another Account\",\n            \"tillNumber\": \"0000002\",\n        },\n        \"status\": \"successful\",\n        \"reasonForFailure\": null,\n        \"reference\": \"ref-3\",\n        \"lencoReference\": \"240010002\",\n        \"extraData\": {\n            \"nipSessionId\": null\n        },\n        \"source\": \"api\"\n    }\n}"
                  }
                }
              }
            }
          },
          "400": {
            "description": "400",
            "content": {
              "application/json": {
                "examples": {
                  "Result": {
                    "value": "{\n    \"status\": false,\n    \"message\": \"Duplicate reference\",\n    \"data\": null\n}"
                  }
                },
                "schema": {
                  "type": "object",
                  "properties": {
                    "status": {
                      "type": "boolean",
                      "example": false,
                      "default": true
                    },
                    "message": {
                      "type": "string",
                      "example": "Duplicate reference"
                    },
                    "data": {}
                  }
                }
              }
            }
          }
        },
        "deprecated": false
      }
    }
  },
  "x-readme": {
    "headers": [],
    "explorer-enabled": false,
    "proxy-enabled": true
  },
  "x-readme-fauxas": true,
  "_id": "65f06b6583c5de0051b8aa08:65f1bdcd8309b5006767f689"
}
```

/collections

# /collections

Response Schema:

```json
{
    "status": boolean,
    "message": string,
    "data": [
        {
            "id": string,
            "initiatedAt": date-time,
            "completedAt": date-time | null,
            "amount": string,
            "fee": string | null,
            "bearer": "merchant" | "customer",
            "currency": string,
            "reference": string | null,
            "lencoReference": string,
            "type": "card" | "mobile-money" | "bank-account" | null,
            "status": "pending" | "successful" | "failed" | "pay-offline" | "3ds-auth-required",
            "source": "banking-app" | "api",
            "reasonForFailure": string | null,
            "settlementStatus": "pending" | "settled" | null,
            "settlement": {
                "id": string,
                "amountSettled": string,
                "currency": string,
                "createdAt": date-time,
                "settledAt": date-time | null,
                "status": "pending" | "settled",
                "type": "instant" | "next-day",
                "accountId": string,
            } | null,
            "mobileMoneyDetails": {
                "country": string,
                "phone": string,
                "operator": string,
                "accountName": string | null,
                "operatorTransactionId": string | null,
            } | null,
            "bankAccountDetails": null,
            "cardDetails": null,
        }
    ],
    "meta": {
        "total": number,
        "pageCount": number,
        "perPage": number,
        "currentPage": number
    }
}
```

# OpenAPI definition

```json
{
  "openapi": "3.1.0",
  "info": {
    "title": "Lenco API",
    "version": "2.0"
  },
  "servers": [
    {
      "url": "https://api.lenco.co/access/v2"
    }
  ],
  "components": {
    "securitySchemes": {
      "sec0": {
        "type": "apiKey",
        "in": "header",
        "name": "Authorization",
        "x-bearer-format": "bearer",
        "x-default": "xo+CAiijrIy9XvZCYyhjrv0fpSAL6CfU8CgA+up1NXqK"
      }
    }
  },
  "security": [
    {
      "sec0": []
    }
  ],
  "paths": {
    "/collections": {
      "get": {
        "summary": "/collections",
        "description": "",
        "operationId": "get-collections",
        "parameters": [
          {
            "name": "page",
            "in": "query",
            "description": "If not specified, it defaults to 1",
            "schema": {
              "type": "integer",
              "format": "int32",
              "default": 1
            }
          },
          {
            "name": "from",
            "in": "query",
            "schema": {
              "type": "string",
              "format": "date"
            }
          },
          {
            "name": "to",
            "in": "query",
            "schema": {
              "type": "string",
              "format": "date"
            }
          },
          {
            "name": "status",
            "in": "query",
            "description": "Either `pending`, `successful`, `failed`, or `pay-offline`",
            "schema": {
              "type": "string",
              "enum": [
                "pending",
                "successful",
                "failed",
                "pay-offline"
              ]
            }
          },
          {
            "name": "type",
            "in": "query",
            "description": "Either `card`, `mobile-money`, or `bank-account`",
            "schema": {
              "type": "string",
              "enum": [
                "card",
                "mobile-money",
                "bank-account"
              ]
            }
          },
          {
            "name": "country",
            "in": "query",
            "description": "i.e. `ng`, `zm`",
            "schema": {
              "type": "string"
            }
          }
        ],
        "responses": {
          "200": {
            "description": "200",
            "content": {
              "application/json": {
                "examples": {
                  "Result": {
                    "value": "{\n    \"status\": true,\n    \"message\": \"\",\n    \"data\": [\n        {\n            \"id\": \"d7bd9ccb-0737-4e72-a387-d00454341f21\",\n            \"initiatedAt\": \"2024-03-12T07:06:11.562Z\",\n            \"completedAt\": \"2024-03-12T07:14:10.412Z\",\n            \"amount\": \"10.00\",\n            \"fee\": \"0.25\",\n            \"bearer\": \"merchant\",\n            \"currency\": \"ZMW\",\n            \"reference\": \"ref-1\",\n            \"lencoReference\": \"240720004\",\n            \"type\": \"mobile-money\",\n            \"status\": \"successful\",\n            \"source\": \"api\",\n            \"reasonForFailure\": null,\n            \"settlementStatus\": \"settled\",\n            \"settlement\": {\n                \"id\": \"c04583d7-d026-4dfa-b8b5-e96f17f93bb8\",\n                \"amountSettled\": \"9.75\",\n                \"currency\": \"ZMW\",\n                \"createdAt\": \"2024-03-12T07:14:10.439Z\",\n                \"settledAt\": \"2024-03-12T07:14:10.496Z\",\n                \"status\": \"settled\",\n                \"type\": \"instant\",\n                \"accountId\": \"68f11209-451f-4a15-bfcd-d916eb8b09f4\"\n            },\n            \"mobileMoneyDetails\": {\n                \"country\": \"zm\",\n                \"phone\": \"0977433571\",\n                \"operator\": \"airtel\",\n                \"accountName\": \"Beata Jean\",\n                \"operatorTransactionId\": \"MP240312.0000.A00001\"\n            },\n            \"bankAccountDetails\": null,\n            \"cardDetails\": null\n        }\n    ],\n    \"meta\": {\n        \"total\": 1,\n        \"pageCount\": 1,\n        \"perPage\": 100,\n        \"currentPage\": 1\n    }\n}"
                  }
                },
                "schema": {
                  "type": "object",
                  "properties": {
                    "status": {
                      "type": "boolean",
                      "example": true,
                      "default": true
                    },
                    "message": {
                      "type": "string",
                      "example": ""
                    },
                    "data": {
                      "type": "array",
                      "items": {
                        "type": "object",
                        "properties": {
                          "id": {
                            "type": "string",
                            "example": "d7bd9ccb-0737-4e72-a387-d00454341f21"
                          },
                          "initiatedAt": {
                            "type": "string",
                            "example": "2024-03-12T07:06:11.562Z"
                          },
                          "completedAt": {
                            "type": "string",
                            "example": "2024-03-12T07:14:10.412Z"
                          },
                          "amount": {
                            "type": "string",
                            "example": "10.00"
                          },
                          "fee": {
                            "type": "string",
                            "example": "0.25"
                          },
                          "bearer": {
                            "type": "string",
                            "example": "merchant"
                          },
                          "currency": {
                            "type": "string",
                            "example": "ZMW"
                          },
                          "reference": {
                            "type": "string",
                            "example": "ref-1"
                          },
                          "lencoReference": {
                            "type": "string",
                            "example": "240720004"
                          },
                          "type": {
                            "type": "string",
                            "example": "mobile-money"
                          },
                          "status": {
                            "type": "string",
                            "example": "successful"
                          },
                          "source": {
                            "type": "string",
                            "example": "api"
                          },
                          "reasonForFailure": {},
                          "settlementStatus": {
                            "type": "string",
                            "example": "settled"
                          },
                          "settlement": {
                            "type": "object",
                            "properties": {
                              "id": {
                                "type": "string",
                                "example": "c04583d7-d026-4dfa-b8b5-e96f17f93bb8"
                              },
                              "amountSettled": {
                                "type": "string",
                                "example": "9.75"
                              },
                              "currency": {
                                "type": "string",
                                "example": "ZMW"
                              },
                              "createdAt": {
                                "type": "string",
                                "example": "2024-03-12T07:14:10.439Z"
                              },
                              "settledAt": {
                                "type": "string",
                                "example": "2024-03-12T07:14:10.496Z"
                              },
                              "status": {
                                "type": "string",
                                "example": "settled"
                              },
                              "type": {
                                "type": "string",
                                "example": "instant"
                              },
                              "accountId": {
                                "type": "string",
                                "example": "68f11209-451f-4a15-bfcd-d916eb8b09f4"
                              }
                            }
                          },
                          "mobileMoneyDetails": {
                            "type": "object",
                            "properties": {
                              "country": {
                                "type": "string",
                                "example": "zm"
                              },
                              "phone": {
                                "type": "string",
                                "example": "0977433571"
                              },
                              "operator": {
                                "type": "string",
                                "example": "airtel"
                              },
                              "accountName": {
                                "type": "string",
                                "example": "Beata Jean"
                              },
                              "operatorTransactionId": {
                                "type": "string",
                                "example": "MP240312.0000.A00001"
                              }
                            }
                          },
                          "bankAccountDetails": {},
                          "cardDetails": {}
                        }
                      }
                    },
                    "meta": {
                      "type": "object",
                      "properties": {
                        "total": {
                          "type": "integer",
                          "example": 1,
                          "default": 0
                        },
                        "pageCount": {
                          "type": "integer",
                          "example": 1,
                          "default": 0
                        },
                        "perPage": {
                          "type": "integer",
                          "example": 100,
                          "default": 0
                        },
                        "currentPage": {
                          "type": "integer",
                          "example": 1,
                          "default": 0
                        }
                      }
                    }
                  }
                }
              }
            }
          }
        },
        "deprecated": false
      }
    }
  },
  "x-readme": {
    "headers": [],
    "explorer-enabled": false,
    "proxy-enabled": true
  },
  "x-readme-fauxas": true,
  "_id": "65f06b6583c5de0051b8aa08:65f19c807fd84800387a2f99"
}
```

/collections/:id

# /collections/:id

Retrieve information about a specific collection request

Response Schema:

```json
{
    "status": boolean,
    "message": string,
    "data": {
        "id": string,
        "initiatedAt": date-time,
        "completedAt": date-time | null,
        "amount": string,
        "fee": string | null,
        "bearer": "merchant" | "customer",
        "currency": string,
        "reference": string | null,
        "lencoReference": string,
        "type": "card" | "mobile-money" | "bank-account" | null,
        "status": "pending" | "successful" | "failed" | "pay-offline" | "3ds-auth-required",
        "source": "banking-app" | "api",
        "reasonForFailure": string | null,
        "settlementStatus": "pending" | "settled" | null,
        "settlement": {
            "id": string,
            "amountSettled": string,
            "currency": string,
            "createdAt": date-time,
            "settledAt": date-time | null,
            "status": "pending" | "settled",
            "type": "instant" | "next-day",
            "accountId": string,
        } | null,
        "mobileMoneyDetails": {
            "country": string,
            "phone": string,
            "operator": string,
            "accountName": string | null,
            "operatorTransactionId": string | null,
        } | null,
        "bankAccountDetails": null,
        "cardDetails": {
            "firstName": string | null,
            "lastName": string | null,
            "bin": string | null,
            "last4": string | null,
            "cardType": string | null,
        } | null,
    }
}
```

# OpenAPI definition

```json
{
  "openapi": "3.1.0",
  "info": {
    "title": "Lenco API",
    "version": "2.0"
  },
  "servers": [
    {
      "url": "https://api.lenco.co/access/v2"
    }
  ],
  "components": {
    "securitySchemes": {
      "sec0": {
        "type": "apiKey",
        "in": "header",
        "name": "Authorization",
        "x-bearer-format": "bearer",
        "x-default": "xo+CAiijrIy9XvZCYyhjrv0fpSAL6CfU8CgA+up1NXqK"
      }
    }
  },
  "security": [
    {
      "sec0": []
    }
  ],
  "paths": {
    "/collections/{id}": {
      "get": {
        "summary": "/collections/:id",
        "description": "Retrieve information about a specific collection request",
        "operationId": "get-collection-by-id",
        "parameters": [
          {
            "name": "id",
            "in": "path",
            "description": "Your 36-character collection uuid",
            "schema": {
              "type": "string"
            },
            "required": true
          }
        ],
        "responses": {
          "200": {
            "description": "200",
            "content": {
              "application/json": {
                "examples": {
                  "Result": {
                    "value": "{\n    \"status\": true,\n    \"message\": \"\",\n    \"data\": {\n        \"id\": \"d7bd9ccb-0737-4e72-a387-d00454341f21\",\n        \"initiatedAt\": \"2024-03-12T07:06:11.562Z\",\n        \"completedAt\": \"2024-03-12T07:14:10.412Z\",\n        \"amount\": \"10.00\",\n        \"fee\": \"0.25\",\n        \"bearer\": \"merchant\",\n        \"currency\": \"ZMW\",\n        \"reference\": \"ref-1\",\n        \"lencoReference\": \"240720004\",\n        \"type\": \"mobile-money\",\n        \"status\": \"successful\",\n        \"source\": \"api\",\n        \"reasonForFailure\": null,\n        \"settlementStatus\": \"settled\",\n        \"settlement\": {\n            \"id\": \"c04583d7-d026-4dfa-b8b5-e96f17f93bb8\",\n            \"amountSettled\": \"9.75\",\n            \"currency\": \"ZMW\",\n            \"createdAt\": \"2024-03-12T07:14:10.439Z\",\n            \"settledAt\": \"2024-03-12T07:14:10.496Z\",\n            \"status\": \"settled\",\n            \"type\": \"instant\",\n            \"accountId\": \"68f11209-451f-4a15-bfcd-d916eb8b09f4\"\n        },\n        \"mobileMoneyDetails\": {\n            \"country\": \"zm\",\n            \"phone\": \"0977433571\",\n            \"operator\": \"airtel\",\n            \"accountName\": \"Beata Jean\",\n            \"operatorTransactionId\": \"MP240312.0000.A00001\"\n        },\n        \"bankAccountDetails\": null,\n        \"cardDetails\": null\n    }\n}"
                  }
                },
                "schema": {
                  "type": "object",
                  "properties": {
                    "status": {
                      "type": "boolean",
                      "example": true,
                      "default": true
                    },
                    "message": {
                      "type": "string",
                      "example": ""
                    },
                    "data": {
                      "type": "object",
                      "properties": {
                        "id": {
                          "type": "string",
                          "example": "d7bd9ccb-0737-4e72-a387-d00454341f21"
                        },
                        "initiatedAt": {
                          "type": "string",
                          "example": "2024-03-12T07:06:11.562Z"
                        },
                        "completedAt": {
                          "type": "string",
                          "example": "2024-03-12T07:14:10.412Z"
                        },
                        "amount": {
                          "type": "string",
                          "example": "10.00"
                        },
                        "fee": {
                          "type": "string",
                          "example": "0.25"
                        },
                        "bearer": {
                          "type": "string",
                          "example": "merchant"
                        },
                        "currency": {
                          "type": "string",
                          "example": "ZMW"
                        },
                        "reference": {
                          "type": "string",
                          "example": "ref-1"
                        },
                        "lencoReference": {
                          "type": "string",
                          "example": "240720004"
                        },
                        "type": {
                          "type": "string",
                          "example": "mobile-money"
                        },
                        "status": {
                          "type": "string",
                          "example": "successful"
                        },
                        "source": {
                          "type": "string",
                          "example": "api"
                        },
                        "reasonForFailure": {},
                        "settlementStatus": {
                          "type": "string",
                          "example": "settled"
                        },
                        "settlement": {
                          "type": "object",
                          "properties": {
                            "id": {
                              "type": "string",
                              "example": "c04583d7-d026-4dfa-b8b5-e96f17f93bb8"
                            },
                            "amountSettled": {
                              "type": "string",
                              "example": "9.75"
                            },
                            "currency": {
                              "type": "string",
                              "example": "ZMW"
                            },
                            "createdAt": {
                              "type": "string",
                              "example": "2024-03-12T07:14:10.439Z"
                            },
                            "settledAt": {
                              "type": "string",
                              "example": "2024-03-12T07:14:10.496Z"
                            },
                            "status": {
                              "type": "string",
                              "example": "settled"
                            },
                            "type": {
                              "type": "string",
                              "example": "instant"
                            },
                            "accountId": {
                              "type": "string",
                              "example": "68f11209-451f-4a15-bfcd-d916eb8b09f4"
                            }
                          }
                        },
                        "mobileMoneyDetails": {
                          "type": "object",
                          "properties": {
                            "country": {
                              "type": "string",
                              "example": "zm"
                            },
                            "phone": {
                              "type": "string",
                              "example": "0977433571"
                            },
                            "operator": {
                              "type": "string",
                              "example": "airtel"
                            },
                            "accountName": {
                              "type": "string",
                              "example": "Beata Jean"
                            },
                            "operatorTransactionId": {
                              "type": "string",
                              "example": "MP240312.0000.A00001"
                            }
                          }
                        },
                        "bankAccountDetails": {},
                        "cardDetails": {}
                      }
                    }
                  }
                }
              }
            }
          },
          "404": {
            "description": "404",
            "content": {
              "application/json": {
                "examples": {
                  "Result": {
                    "value": "{\n    \"status\": false,\n    \"message\": \"Payment details was not found\",\n    \"data\": null\n}"
                  }
                },
                "schema": {
                  "type": "object",
                  "properties": {
                    "status": {
                      "type": "boolean",
                      "example": false,
                      "default": true
                    },
                    "message": {
                      "type": "string",
                      "example": "Payment details was not found"
                    },
                    "data": {}
                  }
                }
              }
            }
          }
        },
        "deprecated": false
      }
    }
  },
  "x-readme": {
    "headers": [],
    "explorer-enabled": false,
    "proxy-enabled": true
  },
  "x-readme-fauxas": true,
  "_id": "65f06b6583c5de0051b8aa08:65f19ca0188ade00750e42d3"
}
```

/collections/status/:reference

# /collections/status/:reference

Retrieve information about a specific collection request using the reference of the request

Response Schema:

```json
{
    "status": boolean,
    "message": string,
    "data": {
        "id": string,
        "initiatedAt": date-time,
        "completedAt": date-time | null,
        "amount": string,
        "fee": string | null,
        "bearer": "merchant" | "customer",
        "currency": string,
        "reference": string | null,
        "lencoReference": string,
        "type": "card" | "mobile-money" | "bank-account" | null,
        "status": "pending" | "successful" | "failed" | "pay-offline" | "3ds-auth-required",
        "source": "banking-app" | "api",
        "reasonForFailure": string | null,
        "settlementStatus": "pending" | "settled" | null,
        "settlement": {
            "id": string,
            "amountSettled": string,
            "currency": string,
            "createdAt": date-time,
            "settledAt": date-time | null,
            "status": "pending" | "settled",
            "type": "instant" | "next-day",
            "accountId": string,
        } | null,
        "mobileMoneyDetails": {
            "country": string,
            "phone": string,
            "operator": string,
            "accountName": string | null,
            "operatorTransactionId": string | null,
        } | null,
        "bankAccountDetails": null,
        "cardDetails": {
            "firstName": string | null,
            "lastName": string | null,
            "bin": string | null,
            "last4": string | null,
            "cardType": string | null,
        } | null,
    }
}
```

# OpenAPI definition

```json
{
  "openapi": "3.1.0",
  "info": {
    "title": "Lenco API",
    "version": "2.0"
  },
  "servers": [
    {
      "url": "https://api.lenco.co/access/v2"
    }
  ],
  "components": {
    "securitySchemes": {
      "sec0": {
        "type": "apiKey",
        "in": "header",
        "name": "Authorization",
        "x-bearer-format": "bearer",
        "x-default": "xo+CAiijrIy9XvZCYyhjrv0fpSAL6CfU8CgA+up1NXqK"
      }
    }
  },
  "security": [
    {
      "sec0": []
    }
  ],
  "paths": {
    "/collections/status/{reference}": {
      "get": {
        "summary": "/collections/status/:reference",
        "description": "Retrieve information about a specific collection request using the reference of the request",
        "operationId": "get-collection-by-reference",
        "parameters": [
          {
            "name": "reference",
            "in": "path",
            "schema": {
              "type": "string"
            },
            "required": true
          }
        ],
        "responses": {
          "200": {
            "description": "200",
            "content": {
              "application/json": {
                "examples": {
                  "Result": {
                    "value": "{\n    \"status\": true,\n    \"message\": \"\",\n    \"data\": {\n        \"id\": \"d7bd9ccb-0737-4e72-a387-d00454341f21\",\n        \"initiatedAt\": \"2024-03-12T07:06:11.562Z\",\n        \"completedAt\": \"2024-03-12T07:14:10.412Z\",\n        \"amount\": \"10.00\",\n        \"fee\": \"0.25\",\n        \"bearer\": \"merchant\",\n        \"currency\": \"ZMW\",\n        \"reference\": \"ref-1\",\n        \"lencoReference\": \"240720004\",\n        \"type\": \"mobile-money\",\n        \"status\": \"successful\",\n        \"source\": \"api\",\n        \"reasonForFailure\": null,\n        \"settlementStatus\": \"settled\",\n        \"settlement\": {\n            \"id\": \"c04583d7-d026-4dfa-b8b5-e96f17f93bb8\",\n            \"amountSettled\": \"9.75\",\n            \"currency\": \"ZMW\",\n            \"createdAt\": \"2024-03-12T07:14:10.439Z\",\n            \"settledAt\": \"2024-03-12T07:14:10.496Z\",\n            \"status\": \"settled\",\n            \"type\": \"instant\",\n            \"accountId\": \"68f11209-451f-4a15-bfcd-d916eb8b09f4\"\n        },\n        \"mobileMoneyDetails\": {\n            \"country\": \"zm\",\n            \"phone\": \"0977433571\",\n            \"operator\": \"airtel\",\n            \"accountName\": \"Beata Jean\",\n            \"operatorTransactionId\": \"MP240312.0000.A00001\"\n        },\n        \"bankAccountDetails\": null,\n        \"cardDetails\": null\n    }\n}"
                  }
                },
                "schema": {
                  "type": "object",
                  "properties": {
                    "status": {
                      "type": "boolean",
                      "example": true,
                      "default": true
                    },
                    "message": {
                      "type": "string",
                      "example": ""
                    },
                    "data": {
                      "type": "object",
                      "properties": {
                        "id": {
                          "type": "string",
                          "example": "d7bd9ccb-0737-4e72-a387-d00454341f21"
                        },
                        "initiatedAt": {
                          "type": "string",
                          "example": "2024-03-12T07:06:11.562Z"
                        },
                        "completedAt": {
                          "type": "string",
                          "example": "2024-03-12T07:14:10.412Z"
                        },
                        "amount": {
                          "type": "string",
                          "example": "10.00"
                        },
                        "fee": {
                          "type": "string",
                          "example": "0.25"
                        },
                        "bearer": {
                          "type": "string",
                          "example": "merchant"
                        },
                        "currency": {
                          "type": "string",
                          "example": "ZMW"
                        },
                        "reference": {
                          "type": "string",
                          "example": "ref-1"
                        },
                        "lencoReference": {
                          "type": "string",
                          "example": "240720004"
                        },
                        "type": {
                          "type": "string",
                          "example": "mobile-money"
                        },
                        "status": {
                          "type": "string",
                          "example": "successful"
                        },
                        "source": {
                          "type": "string",
                          "example": "api"
                        },
                        "reasonForFailure": {},
                        "settlementStatus": {
                          "type": "string",
                          "example": "settled"
                        },
                        "settlement": {
                          "type": "object",
                          "properties": {
                            "id": {
                              "type": "string",
                              "example": "c04583d7-d026-4dfa-b8b5-e96f17f93bb8"
                            },
                            "amountSettled": {
                              "type": "string",
                              "example": "9.75"
                            },
                            "currency": {
                              "type": "string",
                              "example": "ZMW"
                            },
                            "createdAt": {
                              "type": "string",
                              "example": "2024-03-12T07:14:10.439Z"
                            },
                            "settledAt": {
                              "type": "string",
                              "example": "2024-03-12T07:14:10.496Z"
                            },
                            "status": {
                              "type": "string",
                              "example": "settled"
                            },
                            "type": {
                              "type": "string",
                              "example": "instant"
                            },
                            "accountId": {
                              "type": "string",
                              "example": "68f11209-451f-4a15-bfcd-d916eb8b09f4"
                            }
                          }
                        },
                        "mobileMoneyDetails": {
                          "type": "object",
                          "properties": {
                            "country": {
                              "type": "string",
                              "example": "zm"
                            },
                            "phone": {
                              "type": "string",
                              "example": "0977433571"
                            },
                            "operator": {
                              "type": "string",
                              "example": "airtel"
                            },
                            "accountName": {
                              "type": "string",
                              "example": "Beata Jean"
                            },
                            "operatorTransactionId": {
                              "type": "string",
                              "example": "MP240312.0000.A00001"
                            }
                          }
                        },
                        "bankAccountDetails": {},
                        "cardDetails": {}
                      }
                    }
                  }
                }
              }
            }
          },
          "404": {
            "description": "404",
            "content": {
              "application/json": {
                "examples": {
                  "Result": {
                    "value": "{\n    \"status\": false,\n    \"message\": \"Payment details was not found\",\n    \"data\": null\n}"
                  }
                },
                "schema": {
                  "type": "object",
                  "properties": {
                    "status": {
                      "type": "boolean",
                      "example": false,
                      "default": true
                    },
                    "message": {
                      "type": "string",
                      "example": "Payment details was not found"
                    },
                    "data": {}
                  }
                }
              }
            }
          }
        },
        "deprecated": false
      }
    }
  },
  "x-readme": {
    "headers": [],
    "explorer-enabled": false,
    "proxy-enabled": true
  },
  "x-readme-fauxas": true,
  "_id": "65f06b6583c5de0051b8aa08:65f19cbd25d1d1000ff4c00e"
}
```

/collections/mobile-money

# /collections/mobile-money

This endpoint allows you to request a payment from customers by using their phone number enabled for mobile money.

At the point of payment, the customer is required to authorize the payment on their mobile phones. The status of the collection request would be `pay-offline`.\
Once you get this status, you should notify the customer to complete the authorization process on their mobile phones and then listen for webhook notification or requery the [collection request status endpoint](https://lenco-api.readme.io/v2.0/reference/get-collection-by-reference) at interval.

Response Schema:

```json
{
    "status": boolean,
    "message": string,
    "data": {
        "id": string,
        "initiatedAt": date-time,
        "completedAt": date-time | null,
        "amount": string,
        "fee": string | null,
        "bearer": "merchant" | "customer",
        "currency": string,
        "reference": string,
        "lencoReference": string,
        "type": "mobile-money",
        "status": "pending" | "successful" | "failed" | "pay-offline",
        "source": "api",
        "reasonForFailure": string | null,
        "settlementStatus": "pending" | "settled" | null,
        "settlement": null,
        "mobileMoneyDetails": {
            "country": string,
            "phone": string,
            "operator": string,
            "accountName": string | null,
            "operatorTransactionId": string | null,
        } | null,
        "bankAccountDetails": null,
        "cardDetails": null,
    }
}
```

> 📘
>
> You can use any of the accounts [listed here](https://lenco-api.readme.io/v2.0/reference/test-cards-and-accounts) to test mobile money collections in the sandbox environment

# OpenAPI definition

```json
{
  "openapi": "3.1.0",
  "info": {
    "title": "Lenco API",
    "version": "2.0"
  },
  "servers": [
    {
      "url": "https://api.lenco.co/access/v2"
    }
  ],
  "components": {
    "securitySchemes": {
      "sec0": {
        "type": "apiKey",
        "in": "header",
        "name": "Authorization",
        "x-bearer-format": "bearer",
        "x-default": "xo+CAiijrIy9XvZCYyhjrv0fpSAL6CfU8CgA+up1NXqK"
      }
    }
  },
  "security": [
    {
      "sec0": []
    }
  ],
  "paths": {
    "/collections/mobile-money": {
      "post": {
        "summary": "/collections/mobile-money",
        "description": "",
        "operationId": "initiate-collection-from-mobile-money",
        "requestBody": {
          "content": {
            "application/json": {
              "schema": {
                "type": "object",
                "required": [
                  "amount",
                  "reference",
                  "phone",
                  "operator"
                ],
                "properties": {
                  "amount": {
                    "type": "number",
                    "format": "double"
                  },
                  "reference": {
                    "type": "string",
                    "description": "Unique reference. Only `-`, `.`, `_` and alphanumeric characters allowed"
                  },
                  "phone": {
                    "type": "string"
                  },
                  "operator": {
                    "type": "string",
                    "description": "For Zambia, either `airtel`, or `mtn` <br>For Malawi, either `airtel`, or `tnm`",
                    "enum": [
                      "airtel",
                      "mtn",
                      "tnm"
                    ]
                  },
                  "country": {
                    "type": "string",
                    "description": "Optional. Either `zm` (Zambia), or `mw` (Malawi)",
                    "enum": [
                      "zm",
                      "mw"
                    ]
                  },
                  "bearer": {
                    "type": "string",
                    "description": "Optional. Decide who will bear the fee. Either `merchant` (you), or `customer` (your customer)",
                    "default": "merchant",
                    "enum": [
                      "merchant",
                      "customer"
                    ]
                  }
                }
              }
            }
          }
        },
        "responses": {
          "200": {
            "description": "200",
            "content": {
              "application/json": {
                "examples": {
                  "Result": {
                    "value": "{\n    \"status\": true,\n    \"message\": \"\",\n    \"data\": {\n        \"id\": \"e809a3de-3a9f-4a62-9e9b-077311a1924f\",\n        \"initiatedAt\": \"2024-03-13T17:06:44.778Z\",\n        \"completedAt\": null,\n        \"amount\": \"13.00\",\n        \"fee\": null,\n        \"bearer\": \"merchant\",\n        \"currency\": \"ZMW\",\n        \"reference\": \"ref-1\",\n        \"lencoReference\": \"240730008\",\n        \"type\": \"mobile-money\",\n        \"status\": \"pay-offline\",\n        \"source\": \"api\",\n        \"reasonForFailure\": null,\n        \"settlementStatus\": null,\n        \"settlement\": null,\n        \"mobileMoneyDetails\": {\n            \"country\": \"zm\",\n            \"phone\": \"0977433571\",\n            \"operator\": \"airtel\",\n            \"accountName\": \"Haim Hasegawa\",\n            \"operatorTransactionId\": null\n        },\n        \"bankAccountDetails\": null,\n        \"cardDetails\": null\n    }\n}"
                  }
                },
                "schema": {
                  "type": "object",
                  "properties": {
                    "status": {
                      "type": "boolean",
                      "example": true,
                      "default": true
                    },
                    "message": {
                      "type": "string",
                      "example": ""
                    },
                    "data": {
                      "type": "object",
                      "properties": {
                        "id": {
                          "type": "string",
                          "example": "e809a3de-3a9f-4a62-9e9b-077311a1924f"
                        },
                        "initiatedAt": {
                          "type": "string",
                          "example": "2024-03-13T17:06:44.778Z"
                        },
                        "completedAt": {},
                        "amount": {
                          "type": "string",
                          "example": "13.00"
                        },
                        "fee": {},
                        "bearer": {
                          "type": "string",
                          "example": "merchant"
                        },
                        "currency": {
                          "type": "string",
                          "example": "ZMW"
                        },
                        "reference": {
                          "type": "string",
                          "example": "ref-1"
                        },
                        "lencoReference": {
                          "type": "string",
                          "example": "240730008"
                        },
                        "type": {
                          "type": "string",
                          "example": "mobile-money"
                        },
                        "status": {
                          "type": "string",
                          "example": "pay-offline"
                        },
                        "source": {
                          "type": "string",
                          "example": "api"
                        },
                        "reasonForFailure": {},
                        "settlementStatus": {},
                        "settlement": {},
                        "mobileMoneyDetails": {
                          "type": "object",
                          "properties": {
                            "country": {
                              "type": "string",
                              "example": "zm"
                            },
                            "phone": {
                              "type": "string",
                              "example": "0977433571"
                            },
                            "operator": {
                              "type": "string",
                              "example": "airtel"
                            },
                            "accountName": {
                              "type": "string",
                              "example": "Haim Hasegawa"
                            },
                            "operatorTransactionId": {}
                          }
                        },
                        "bankAccountDetails": {},
                        "cardDetails": {}
                      }
                    }
                  }
                }
              }
            }
          },
          "400": {
            "description": "400",
            "content": {
              "application/json": {
                "examples": {
                  "Result": {
                    "value": "{\n  \"status\": false,\n  \"message\": \"Duplicate reference\",\n  \"data\": null\n}"
                  }
                },
                "schema": {
                  "type": "object",
                  "properties": {
                    "status": {
                      "type": "boolean",
                      "example": false,
                      "default": true
                    },
                    "message": {
                      "type": "string",
                      "example": "Duplicate reference"
                    },
                    "data": {}
                  }
                }
              }
            }
          }
        },
        "deprecated": false
      }
    }
  },
  "x-readme": {
    "headers": [],
    "explorer-enabled": false,
    "proxy-enabled": true
  },
  "x-readme-fauxas": true,
  "_id": "65f06b6583c5de0051b8aa08:65f19d00c6b26e001c6266d2"
}
```

/collections/card

# /collections/card

> 📘 PCI DSS required
>
> Using this endpoint involves dealing with cardholder Personally Identifying Information (PII). A Payment Card Industry Data Security Standard (PCI DSS) certificate is therefore required.

This endpoint allows you to request a payment from customers by charging their debit/credit cards.

You send the customer details along with the card and billing information.

**Request**

The request payload would be encrypted. Please follow the guide [here](https://lenco-api.readme.io/v2.0/reference/encryption).\
The parameters you can use to build the request payload are given below:

[block:parameters]
{
  "data": {
    "h-0": "Param",
    "h-1": "Required?",
    "h-2": "Description",
    "0-0": "email",
    "0-1": "Yes",
    "0-2": "Email address of customer",
    "1-0": "reference",
    "1-1": "Yes",
    "1-2": "Unique case sensitive reference. Only `-`, `.`, `_`, and alphanumeric characters allowed",
    "2-0": "amount",
    "2-1": "Yes",
    "2-2": "Amount the customer is to pay. This can include decimals (i.e. 10.75)",
    "3-0": "currency",
    "3-1": "Yes",
    "3-2": "ISO 3-Letter Currency Code e.g. `ZMW`, `USD`",
    "4-0": "bearer",
    "4-1": "No",
    "4-2": "Decide who will bear the fee. Either `merchant` (you), or `customer` (your customer).  \nNote: This will only be used if not already set in your dashboard.",
    "5-0": "customer",
    "5-1": "Yes",
    "5-2": "This field holds the customer details",
    "6-0": "customer.firstName",
    "6-1": "Yes",
    "6-2": "The first name of the customer",
    "7-0": "customer.lastName",
    "7-1": "Yes",
    "7-2": "The last name of the customer",
    "8-0": "billing",
    "8-1": "Yes",
    "8-2": "This field holds the customer's billing address",
    "9-0": "billing.streetAddress",
    "9-1": "Yes",
    "9-2": "The street address",
    "10-0": "billing.city",
    "10-1": "Yes",
    "10-2": "The city ",
    "11-0": "billing.state",
    "11-1": "No",
    "11-2": "The state or province.  \nIf a country does not have states or provinces, this can be left blank.  \n  \nNote: For US states and Canada provinces, this should be the 2-letter code for the state / province. i.e. California should be `CA`.  \n  \nYou can find the list of US State and Canada Province codes [here](https://www.ups.com/worldshiphelp/WSA/ENU/AppHelp/mergedProjects/CORE/Codes/State_Province_Codes.htm)",
    "12-0": "billing.postalCode",
    "12-1": "Yes",
    "12-2": "The postal code",
    "13-0": "billing.country",
    "13-1": "Yes",
    "13-2": "2-letter code i.e. United states should be `US`.  \nYou can find the list of country codes [here](https://www.iban.com/country-codes)",
    "14-0": "card",
    "14-1": "Yes",
    "14-2": "This field holds the card details",
    "15-0": "card.number",
    "15-1": "Yes",
    "15-2": "Card PAN",
    "16-0": "card.expiryMonth",
    "16-1": "Yes",
    "16-2": "Card expiry month",
    "17-0": "card.expiryYear",
    "17-1": "Yes",
    "17-2": "Card expiry year ",
    "18-0": "card.cvv",
    "18-1": "Yes",
    "18-2": "Card security code",
    "19-0": "redirectUrl",
    "19-1": "No",
    "19-2": "The customer will be redirected to this url after completing the payment.  \nYour `reference`, `lencoReference`, `status`, and an optional `errorMessage` will be appended as query parameters to the redirectUrl"
  },
  "cols": 3,
  "rows": 20,
  "align": [
    "left",
    "left",
    "left"
  ]
}
[/block]

```json
// Sample payload to be encrypted

{
  "reference": "test-1",
  "email": "customer@email.com",
  "amount": "1000",
  "currency": "ZMW",
  "bearer": "merchant",
  "customer": {
    "firstName": "John",
    "lastName": "Doe"
  },
  "billing": {
    "streetAddress": "901 metro center blvd",
    "city": "San Francisco",
    "state": "CA",
    "postalCode": "94404",
    "country": "US"
  },
  "card": {
    "number": "5555 5555 5555 4444",
    "cvv": "838",
    "expiryMonth": "12",
    "expiryYear": "2024"
  },
  "redirectUrl": "https://www.yoururl.com/verify_payment"
}
```

<br />

**Response**

For cards that require 3D Secure authorization, the value of `data`.`status` would be "3ds-auth-required" and the response would include an `authorization` object in the `meta` key.\
This `authorization` object would contain a `mode` key which will be "redirect", and a `redirect` key.\
You should redirect your customer to the URL specified in `meta`.`authorization`.`redirect` to complete the 3DS authorization.

```json
// Response Schema

{
    "status": boolean,
    "message": string,
    "data": {
        "id": string,
        "initiatedAt": date-time,
        "completedAt": date-time | null,
        "amount": string,
        "fee": string | null,
        "bearer": "merchant" | "customer",
        "currency": string,
        "reference": string,
        "lencoReference": string,
        "type": "card",
        "status": "pending" | "successful" | "failed" | "3ds-auth-required",
        "source": "api",
        "reasonForFailure": string | null,
        "settlementStatus": "pending" | "settled" | null,
        "settlement": null,
        "mobileMoneyDetails": null,
        "bankAccountDetails": null,
        "cardDetails": {
            "firstName": string | null,
            "lastName": string | null,
            "bin": string | null,
            "last4": string | null,
            "cardType": string | null,
        } | null,
        "meta": { // optional
            "authorization": {
                "mode": "redirect",
                "redirect": string
            }
        }
    }
}
```

> 📘
>
> You can use any of the cards [listed here](https://lenco-api.readme.io/v2.0/reference/test-cards-and-accounts) to test card collections in the sandbox environment

# OpenAPI definition

```json
{
  "openapi": "3.1.0",
  "info": {
    "title": "Lenco API",
    "version": "2.0"
  },
  "servers": [
    {
      "url": "https://api.lenco.co/access/v2"
    }
  ],
  "components": {
    "securitySchemes": {
      "sec0": {
        "type": "apiKey",
        "in": "header",
        "name": "Authorization",
        "x-bearer-format": "bearer",
        "x-default": "xo+CAiijrIy9XvZCYyhjrv0fpSAL6CfU8CgA+up1NXqK"
      }
    }
  },
  "security": [
    {
      "sec0": []
    }
  ],
  "paths": {
    "/collections/card": {
      "post": {
        "summary": "/collections/card",
        "description": "",
        "operationId": "initiate-collection-from-card",
        "requestBody": {
          "content": {
            "application/json": {
              "schema": {
                "type": "object",
                "required": [
                  "encryptedPayload"
                ],
                "properties": {
                  "encryptedPayload": {
                    "type": "string",
                    "description": "JWE encrypted payload. See the [encryption](https://lenco-api.readme.io/v2.0/reference/encryption) guide"
                  }
                }
              }
            }
          }
        },
        "responses": {
          "200": {
            "description": "200",
            "content": {
              "application/json": {
                "examples": {
                  "Result": {
                    "value": "{\n    \"status\": true,\n    \"message\": \"\",\n    \"data\": {\n        \"id\": \"e809a3de-3a9f-4a62-9e9b-077311a1924f\",\n        \"initiatedAt\": \"2024-03-13T17:06:44.778Z\",\n        \"completedAt\": null,\n        \"amount\": \"13.00\",\n        \"fee\": null,\n        \"bearer\": \"merchant\",\n        \"currency\": \"ZMW\",\n        \"reference\": \"ref-1\",\n        \"lencoReference\": \"240730008\",\n        \"type\": \"mobile-money\",\n        \"status\": \"3ds-auth-required\",\n        \"source\": \"api\",\n        \"reasonForFailure\": null,\n        \"settlementStatus\": null,\n        \"settlement\": null,\n        \"mobileMoneyDetails\": null,\n        \"bankAccountDetails\": null,\n        \"cardDetails\": {\n            \"firstName\": \"Haim\",\n            \"lastName\": \"Hasegawa\",\n            \"bin\": \"555555\",\n            \"last4\": \"4444\",\n            \"cardType\": \"Mastercard\"\n        }\n    },\n    \"meta\": {\n        \"authorization\": {\n            \"mode\": \"redirect\",\n            \"redirect\": \"https://pay.lenco.co/auth/03bab921-ba51-4b44-b3da-620928e99c5a\"\n        }\n    }\n}"
                  }
                },
                "schema": {
                  "type": "object",
                  "properties": {
                    "status": {
                      "type": "boolean",
                      "example": true,
                      "default": true
                    },
                    "message": {
                      "type": "string",
                      "example": ""
                    },
                    "data": {
                      "type": "object",
                      "properties": {
                        "id": {
                          "type": "string",
                          "example": "e809a3de-3a9f-4a62-9e9b-077311a1924f"
                        },
                        "initiatedAt": {
                          "type": "string",
                          "example": "2024-03-13T17:06:44.778Z"
                        },
                        "completedAt": {},
                        "amount": {
                          "type": "string",
                          "example": "13.00"
                        },
                        "fee": {},
                        "bearer": {
                          "type": "string",
                          "example": "merchant"
                        },
                        "currency": {
                          "type": "string",
                          "example": "ZMW"
                        },
                        "reference": {
                          "type": "string",
                          "example": "ref-1"
                        },
                        "lencoReference": {
                          "type": "string",
                          "example": "240730008"
                        },
                        "type": {
                          "type": "string",
                          "example": "mobile-money"
                        },
                        "status": {
                          "type": "string",
                          "example": "3ds-auth-required"
                        },
                        "source": {
                          "type": "string",
                          "example": "api"
                        },
                        "reasonForFailure": {},
                        "settlementStatus": {},
                        "settlement": {},
                        "mobileMoneyDetails": {},
                        "bankAccountDetails": {},
                        "cardDetails": {
                          "type": "object",
                          "properties": {
                            "firstName": {
                              "type": "string",
                              "example": "Haim"
                            },
                            "lastName": {
                              "type": "string",
                              "example": "Hasegawa"
                            },
                            "bin": {
                              "type": "string",
                              "example": "555555"
                            },
                            "last4": {
                              "type": "string",
                              "example": "4444"
                            },
                            "cardType": {
                              "type": "string",
                              "example": "Mastercard"
                            }
                          }
                        }
                      }
                    },
                    "meta": {
                      "type": "object",
                      "properties": {
                        "authorization": {
                          "type": "object",
                          "properties": {
                            "mode": {
                              "type": "string",
                              "example": "redirect"
                            },
                            "redirect": {
                              "type": "string",
                              "example": "https://pay.lenco.co/auth/03bab921-ba51-4b44-b3da-620928e99c5a"
                            }
                          }
                        }
                      }
                    }
                  }
                }
              }
            }
          },
          "400": {
            "description": "400",
            "content": {
              "application/json": {
                "examples": {
                  "Result": {
                    "value": "{\n  \"status\": false,\n  \"message\": \"Duplicate reference\",\n  \"data\": null\n}"
                  }
                },
                "schema": {
                  "type": "object",
                  "properties": {
                    "status": {
                      "type": "boolean",
                      "example": false,
                      "default": true
                    },
                    "message": {
                      "type": "string",
                      "example": "Duplicate reference"
                    },
                    "data": {}
                  }
                }
              }
            }
          }
        },
        "deprecated": false
      }
    }
  },
  "x-readme": {
    "headers": [],
    "explorer-enabled": false,
    "proxy-enabled": true
  },
  "x-readme-fauxas": true,
  "_id": "65f06b6583c5de0051b8aa08:671129e8c3a3d20019c293c5"
}
```

/settlements

# /settlements

Retrieve information about all your collection settlements

Response Schema:

```json
{
    "status": boolean,
    "message": string,
    "data": [
        {
            "id": string,
            "amountSettled": string,
            "currency": string,
            "createdAt": date-time,
            "settledAt": date-time | null,
            "status": "pending" | "settled",
            "type": "instant" | "next-day",
            "accountId": string,
            "collection": {
                "id": string,
                "initiatedAt": date-time,
                "completedAt": date-time | null,
                "amount": string,
                "fee": string | null,
                "bearer": "merchant" | "customer",
                "currency": string,
                "reference": string | null,
                "lencoReference": string,
                "type": "card" | "mobile-money" |"bank-account",
                "status": "pending" | "successful" | "failed" | "otp-required" | "pay-offline",
                "source": "banking-app" | "api",
                "reasonForFailure": string | null,
                "settlementStatus": "pending" | "settled" | null,
                "settlement": null,
                "mobileMoneyDetails": {
                    "country": string,
                    "phone": string,
                    "operator": string,
                    "accountName": string | null,
                } | null,
                "bankAccountDetails": null,
                "cardDetails": null,
            };
        }
    ],
    "meta": {
        "total": number,
        "pageCount": number,
        "perPage": number,
        "currentPage": number
    }
}
```

# OpenAPI definition

```json
{
  "openapi": "3.1.0",
  "info": {
    "title": "Lenco API",
    "version": "2.0"
  },
  "servers": [
    {
      "url": "https://api.lenco.co/access/v2"
    }
  ],
  "components": {
    "securitySchemes": {
      "sec0": {
        "type": "apiKey",
        "in": "header",
        "name": "Authorization",
        "x-bearer-format": "bearer",
        "x-default": "xo+CAiijrIy9XvZCYyhjrv0fpSAL6CfU8CgA+up1NXqK"
      }
    }
  },
  "security": [
    {
      "sec0": []
    }
  ],
  "paths": {
    "/settlements": {
      "get": {
        "summary": "/settlements",
        "description": "Retrieve information about all your collection settlements",
        "operationId": "get-settlements",
        "parameters": [
          {
            "name": "page",
            "in": "query",
            "schema": {
              "type": "integer",
              "format": "int32",
              "default": 1
            }
          },
          {
            "name": "from",
            "in": "query",
            "description": "Format: YYYY-MM-DD",
            "schema": {
              "type": "string",
              "format": "date"
            }
          },
          {
            "name": "to",
            "in": "query",
            "description": "Format: YYYY-MM-DD",
            "schema": {
              "type": "string",
              "format": "date"
            }
          },
          {
            "name": "status",
            "in": "query",
            "description": "`pending` or `settled`",
            "schema": {
              "type": "string"
            }
          },
          {
            "name": "type",
            "in": "query",
            "description": "`instant` or `next-day`",
            "schema": {
              "type": "string"
            }
          },
          {
            "name": "collectionType",
            "in": "query",
            "description": "`card`, `mobile-money`, or `bank-account`",
            "schema": {
              "type": "string"
            }
          },
          {
            "name": "country",
            "in": "query",
            "description": "i.e. `ng`, `zm`",
            "schema": {
              "type": "string"
            }
          }
        ],
        "responses": {
          "200": {
            "description": "200",
            "content": {
              "application/json": {
                "examples": {
                  "Result": {
                    "value": "{\n    \"status\": true,\n    \"message\": \"\",\n    \"data\": [\n        {\n            \"id\": \"c04583d7-d026-4dfa-b8b5-e96f17f93bb8\",\n            \"amountSettled\": \"9.75\",\n            \"currency\": \"ZMW\",\n            \"createdAt\": \"2024-03-12T07:14:10.439Z\",\n            \"settledAt\": \"2024-03-12T07:14:10.496Z\",\n            \"status\": \"settled\",\n            \"type\": \"instant\",\n            \"accountId\": \"68f11209-451f-4a15-bfcd-d916eb8b09f4\",\n            \"collection\": {\n                \"id\": \"d7bd9ccb-0737-4e72-a387-d00454341f21\",\n                \"initiatedAt\": \"2024-03-12T07:06:11.562Z\",\n                \"completedAt\": \"2024-03-12T07:14:10.412Z\",\n                \"amount\": \"10.00\",\n                \"fee\": \"0.25\",\n                \"bearer\": \"merchant\",\n                \"currency\": \"ZMW\",\n                \"reference\": \"ref-1\",\n                \"lencoReference\": \"240010001\",\n                \"type\": \"mobile-money\",\n                \"status\": \"successful\",\n                \"source\": \"api\",\n                \"reasonForFailure\": null,\n                \"settlementStatus\": \"settled\",\n                \"settlement\": null,\n                \"mobileMoneyDetails\": {\n                    \"country\": \"zm\",\n                    \"phone\": \"0977433571\",\n                    \"operator\": \"airtel\",\n                    \"accountName\": \"Beata Jean\"\n                },\n                \"bankAccountDetails\": null,\n                \"cardDetails\": null\n            }\n        }\n    ],\n    \"meta\": {\n        \"total\": 1,\n        \"pageCount\": 1,\n        \"perPage\": 100,\n        \"currentPage\": 1\n    }\n}"
                  }
                },
                "schema": {
                  "type": "object",
                  "properties": {
                    "status": {
                      "type": "boolean",
                      "example": true,
                      "default": true
                    },
                    "message": {
                      "type": "string",
                      "example": ""
                    },
                    "data": {
                      "type": "array",
                      "items": {
                        "type": "object",
                        "properties": {
                          "id": {
                            "type": "string",
                            "example": "c04583d7-d026-4dfa-b8b5-e96f17f93bb8"
                          },
                          "amountSettled": {
                            "type": "string",
                            "example": "9.75"
                          },
                          "currency": {
                            "type": "string",
                            "example": "ZMW"
                          },
                          "createdAt": {
                            "type": "string",
                            "example": "2024-03-12T07:14:10.439Z"
                          },
                          "settledAt": {
                            "type": "string",
                            "example": "2024-03-12T07:14:10.496Z"
                          },
                          "status": {
                            "type": "string",
                            "example": "settled"
                          },
                          "type": {
                            "type": "string",
                            "example": "instant"
                          },
                          "accountId": {
                            "type": "string",
                            "example": "68f11209-451f-4a15-bfcd-d916eb8b09f4"
                          },
                          "collection": {
                            "type": "object",
                            "properties": {
                              "id": {
                                "type": "string",
                                "example": "d7bd9ccb-0737-4e72-a387-d00454341f21"
                              },
                              "initiatedAt": {
                                "type": "string",
                                "example": "2024-03-12T07:06:11.562Z"
                              },
                              "completedAt": {
                                "type": "string",
                                "example": "2024-03-12T07:14:10.412Z"
                              },
                              "amount": {
                                "type": "string",
                                "example": "10.00"
                              },
                              "fee": {
                                "type": "string",
                                "example": "0.25"
                              },
                              "bearer": {
                                "type": "string",
                                "example": "merchant"
                              },
                              "currency": {
                                "type": "string",
                                "example": "ZMW"
                              },
                              "reference": {
                                "type": "string",
                                "example": "ref-1"
                              },
                              "lencoReference": {
                                "type": "string",
                                "example": "240010001"
                              },
                              "type": {
                                "type": "string",
                                "example": "mobile-money"
                              },
                              "status": {
                                "type": "string",
                                "example": "successful"
                              },
                              "source": {
                                "type": "string",
                                "example": "api"
                              },
                              "reasonForFailure": {},
                              "settlementStatus": {
                                "type": "string",
                                "example": "settled"
                              },
                              "settlement": {},
                              "mobileMoneyDetails": {
                                "type": "object",
                                "properties": {
                                  "country": {
                                    "type": "string",
                                    "example": "zm"
                                  },
                                  "phone": {
                                    "type": "string",
                                    "example": "0977433571"
                                  },
                                  "operator": {
                                    "type": "string",
                                    "example": "airtel"
                                  },
                                  "accountName": {
                                    "type": "string",
                                    "example": "Beata Jean"
                                  }
                                }
                              },
                              "bankAccountDetails": {},
                              "cardDetails": {}
                            }
                          }
                        }
                      }
                    },
                    "meta": {
                      "type": "object",
                      "properties": {
                        "total": {
                          "type": "integer",
                          "example": 1,
                          "default": 0
                        },
                        "pageCount": {
                          "type": "integer",
                          "example": 1,
                          "default": 0
                        },
                        "perPage": {
                          "type": "integer",
                          "example": 100,
                          "default": 0
                        },
                        "currentPage": {
                          "type": "integer",
                          "example": 1,
                          "default": 0
                        }
                      }
                    }
                  }
                }
              }
            }
          }
        },
        "deprecated": false
      }
    }
  },
  "x-readme": {
    "headers": [],
    "explorer-enabled": false,
    "proxy-enabled": true
  },
  "x-readme-fauxas": true,
  "_id": "65f06b6583c5de0051b8aa08:65f19c5032047b001acc8f6a"
}
```

/settlements/:id

# /settlements/:id

Retrieve information about a specific settlement

Response Schema:

```json
{
    "status": boolean,
    "message": string,
    "data": {
        "id": string,
        "amountSettled": string,
        "currency": string,
        "createdAt": date-time,
        "settledAt": date-time | null,
        "status": "pending" | "settled",
        "type": "instant" | "next-day",
        "accountId": string,
        "collection": {
            "id": string,
            "initiatedAt": date-time,
            "completedAt": date-time | null,
            "amount": string,
            "fee": string | null,
            "bearer": "merchant" | "customer",
            "currency": string,
            "reference": string | null,
            "lencoReference": string,
            "type": "card" | "mobile-money" |"bank-account",
            "status": "pending" | "successful" | "failed" | "otp-required" | "pay-offline",
            "source": "banking-app" | "api",
            "reasonForFailure": string | null,
            "settlementStatus": "pending" | "settled" | null,
            "settlement": null,
            "mobileMoneyDetails": {
                "country": string,
                "phone": string,
                "operator": string,
                "accountName": string | null,
            } | null,
            "bankAccountDetails": null,
            "cardDetails": null,
        };
    }
}
```

# OpenAPI definition

```json
{
  "openapi": "3.1.0",
  "info": {
    "title": "Lenco API",
    "version": "2.0"
  },
  "servers": [
    {
      "url": "https://api.lenco.co/access/v2"
    }
  ],
  "components": {
    "securitySchemes": {
      "sec0": {
        "type": "apiKey",
        "in": "header",
        "name": "Authorization",
        "x-bearer-format": "bearer",
        "x-default": "xo+CAiijrIy9XvZCYyhjrv0fpSAL6CfU8CgA+up1NXqK"
      }
    }
  },
  "security": [
    {
      "sec0": []
    }
  ],
  "paths": {
    "/settlements/{id}": {
      "get": {
        "summary": "/settlements/:id",
        "description": "Retrieve information about a specific settlement",
        "operationId": "get-settlement-by-id",
        "parameters": [
          {
            "name": "id",
            "in": "path",
            "description": "Your 36-character settlement uuid",
            "schema": {
              "type": "string"
            },
            "required": true
          }
        ],
        "responses": {
          "200": {
            "description": "200",
            "content": {
              "application/json": {
                "examples": {
                  "Result": {
                    "value": "{\n    \"status\": true,\n    \"message\": \"\",\n    \"data\": {\n        \"id\": \"c04583d7-d026-4dfa-b8b5-e96f17f93bb8\",\n        \"amountSettled\": \"9.75\",\n        \"currency\": \"ZMW\",\n        \"createdAt\": \"2024-03-12T07:14:10.439Z\",\n        \"settledAt\": \"2024-03-12T07:14:10.496Z\",\n        \"status\": \"settled\",\n        \"type\": \"instant\",\n        \"accountId\": \"68f11209-451f-4a15-bfcd-d916eb8b09f4\",\n        \"collection\": {\n            \"id\": \"d7bd9ccb-0737-4e72-a387-d00454341f21\",\n            \"initiatedAt\": \"2024-03-12T07:06:11.562Z\",\n            \"completedAt\": \"2024-03-12T07:14:10.412Z\",\n            \"amount\": \"10.00\",\n            \"fee\": \"0.25\",\n            \"bearer\": \"merchant\",\n            \"currency\": \"ZMW\",\n            \"reference\": \"ref-1\",\n            \"lencoReference\": \"240010001\",\n            \"type\": \"mobile-money\",\n            \"status\": \"successful\",\n            \"source\": \"api\",\n            \"reasonForFailure\": null,\n            \"settlementStatus\": \"settled\",\n            \"settlement\": null,\n            \"mobileMoneyDetails\": {\n                \"country\": \"zm\",\n                \"phone\": \"0977433571\",\n                \"operator\": \"airtel\",\n                \"accountName\": \"Beata Jean\"\n            },\n            \"bankAccountDetails\": null,\n            \"cardDetails\": null\n        }\n    }\n}"
                  }
                },
                "schema": {
                  "type": "object",
                  "properties": {
                    "status": {
                      "type": "boolean",
                      "example": true,
                      "default": true
                    },
                    "message": {
                      "type": "string",
                      "example": ""
                    },
                    "data": {
                      "type": "object",
                      "properties": {
                        "id": {
                          "type": "string",
                          "example": "c04583d7-d026-4dfa-b8b5-e96f17f93bb8"
                        },
                        "amountSettled": {
                          "type": "string",
                          "example": "9.75"
                        },
                        "currency": {
                          "type": "string",
                          "example": "ZMW"
                        },
                        "createdAt": {
                          "type": "string",
                          "example": "2024-03-12T07:14:10.439Z"
                        },
                        "settledAt": {
                          "type": "string",
                          "example": "2024-03-12T07:14:10.496Z"
                        },
                        "status": {
                          "type": "string",
                          "example": "settled"
                        },
                        "type": {
                          "type": "string",
                          "example": "instant"
                        },
                        "accountId": {
                          "type": "string",
                          "example": "68f11209-451f-4a15-bfcd-d916eb8b09f4"
                        },
                        "collection": {
                          "type": "object",
                          "properties": {
                            "id": {
                              "type": "string",
                              "example": "d7bd9ccb-0737-4e72-a387-d00454341f21"
                            },
                            "initiatedAt": {
                              "type": "string",
                              "example": "2024-03-12T07:06:11.562Z"
                            },
                            "completedAt": {
                              "type": "string",
                              "example": "2024-03-12T07:14:10.412Z"
                            },
                            "amount": {
                              "type": "string",
                              "example": "10.00"
                            },
                            "fee": {
                              "type": "string",
                              "example": "0.25"
                            },
                            "bearer": {
                              "type": "string",
                              "example": "merchant"
                            },
                            "currency": {
                              "type": "string",
                              "example": "ZMW"
                            },
                            "reference": {
                              "type": "string",
                              "example": "ref-1"
                            },
                            "lencoReference": {
                              "type": "string",
                              "example": "240010001"
                            },
                            "type": {
                              "type": "string",
                              "example": "mobile-money"
                            },
                            "status": {
                              "type": "string",
                              "example": "successful"
                            },
                            "source": {
                              "type": "string",
                              "example": "api"
                            },
                            "reasonForFailure": {},
                            "settlementStatus": {
                              "type": "string",
                              "example": "settled"
                            },
                            "settlement": {},
                            "mobileMoneyDetails": {
                              "type": "object",
                              "properties": {
                                "country": {
                                  "type": "string",
                                  "example": "zm"
                                },
                                "phone": {
                                  "type": "string",
                                  "example": "0977433571"
                                },
                                "operator": {
                                  "type": "string",
                                  "example": "airtel"
                                },
                                "accountName": {
                                  "type": "string",
                                  "example": "Beata Jean"
                                }
                              }
                            },
                            "bankAccountDetails": {},
                            "cardDetails": {}
                          }
                        }
                      }
                    }
                  }
                }
              }
            }
          },
          "404": {
            "description": "404",
            "content": {
              "application/json": {
                "examples": {
                  "Result": {
                    "value": "{\n    \"status\": false,\n    \"message\": \"Settlement was not found\",\n    \"data\": null\n}"
                  }
                },
                "schema": {
                  "type": "object",
                  "properties": {
                    "status": {
                      "type": "boolean",
                      "example": false,
                      "default": true
                    },
                    "message": {
                      "type": "string",
                      "example": "Settlement was not found"
                    },
                    "data": {}
                  }
                }
              }
            }
          }
        },
        "deprecated": false
      }
    }
  },
  "x-readme": {
    "headers": [],
    "explorer-enabled": false,
    "proxy-enabled": true
  },
  "x-readme-fauxas": true,
  "_id": "65f06b6583c5de0051b8aa08:65f19c5e83c98d0074e0910b"
}
```

/transactions

# /transactions

Get transactions that occurred on your accounts

Response Schema:

```json
{
    "status": boolean,
    "message": string,
    "data": [
        {
            "id": string,
            "amount": string,
            "currency": string,
            "narration": string,
            "type": "credit" | "debit",
            "datetime": date-time,
            "accountId": string,
            "balance": string | null
        }
    ],
    "meta": {
        "total": number,
        "pageCount": number,
        "perPage": number,
        "currentPage": number
    }
}
```

# OpenAPI definition

```json
{
  "openapi": "3.1.0",
  "info": {
    "title": "Lenco API",
    "version": "2.0"
  },
  "servers": [
    {
      "url": "https://api.lenco.co/access/v2"
    }
  ],
  "components": {
    "securitySchemes": {
      "sec0": {
        "type": "apiKey",
        "in": "header",
        "name": "Authorization",
        "x-bearer-format": "bearer",
        "x-default": "xo+CAiijrIy9XvZCYyhjrv0fpSAL6CfU8CgA+up1NXqK"
      }
    }
  },
  "security": [
    {
      "sec0": []
    }
  ],
  "paths": {
    "/transactions": {
      "get": {
        "summary": "/transactions",
        "description": "Get transactions that occurred on your accounts",
        "operationId": "get-transactions",
        "parameters": [
          {
            "name": "page",
            "in": "query",
            "description": "If not specified, it defaults to 1",
            "schema": {
              "type": "integer",
              "format": "int32",
              "default": 1
            }
          },
          {
            "name": "type",
            "in": "query",
            "description": "either `credit`, or `debit`",
            "schema": {
              "type": "string"
            }
          },
          {
            "name": "from",
            "in": "query",
            "description": "Format: YYYY-MM-DD",
            "schema": {
              "type": "string",
              "format": "date"
            }
          },
          {
            "name": "to",
            "in": "query",
            "description": "Format: YYYY-MM-DD",
            "schema": {
              "type": "string",
              "format": "date"
            }
          },
          {
            "name": "search",
            "in": "query",
            "description": "Search term to look for",
            "schema": {
              "type": "string"
            }
          },
          {
            "name": "accountId",
            "in": "query",
            "description": "Your 36-character account uuid to filter transactions",
            "schema": {
              "type": "string"
            }
          }
        ],
        "responses": {
          "200": {
            "description": "200",
            "content": {
              "application/json": {
                "examples": {
                  "Result": {
                    "value": "{\n    \"status\": true,\n    \"message\": \"\",\n    \"data\": [\n        {\n            \"id\": \"d6730fe6-77a0-4432-a283-832eaef31786\",\n            \"amount\": \"13.00\",\n            \"currency\": \"ZMW\",\n            \"narration\": \"Transfer / 240730006\",\n            \"type\": \"debit\",\n            \"datetime\": \"2024-01-10T14:24:31.931Z\",\n            \"accountId\": \"b176cda5-7d97-4a3f-b4dd-ab0234e9e08c\",\n            \"balance\": \"997559.00\"\n        }\n    ],\n    \"meta\": {\n        \"total\": 1,\n        \"pageCount\": 1,\n        \"perPage\": 100,\n        \"currentPage\": 1\n    }\n}"
                  }
                },
                "schema": {
                  "type": "object",
                  "properties": {
                    "status": {
                      "type": "boolean",
                      "example": true,
                      "default": true
                    },
                    "message": {
                      "type": "string",
                      "example": ""
                    },
                    "data": {
                      "type": "array",
                      "items": {
                        "type": "object",
                        "properties": {
                          "id": {
                            "type": "string",
                            "example": "d6730fe6-77a0-4432-a283-832eaef31786"
                          },
                          "amount": {
                            "type": "string",
                            "example": "13.00"
                          },
                          "currency": {
                            "type": "string",
                            "example": "ZMW"
                          },
                          "narration": {
                            "type": "string",
                            "example": "Transfer / 240730006"
                          },
                          "type": {
                            "type": "string",
                            "example": "debit"
                          },
                          "datetime": {
                            "type": "string",
                            "example": "2024-01-10T14:24:31.931Z"
                          },
                          "accountId": {
                            "type": "string",
                            "example": "b176cda5-7d97-4a3f-b4dd-ab0234e9e08c"
                          },
                          "balance": {
                            "type": "string",
                            "example": "997559.00"
                          }
                        }
                      }
                    },
                    "meta": {
                      "type": "object",
                      "properties": {
                        "total": {
                          "type": "integer",
                          "example": 1,
                          "default": 0
                        },
                        "pageCount": {
                          "type": "integer",
                          "example": 1,
                          "default": 0
                        },
                        "perPage": {
                          "type": "integer",
                          "example": 100,
                          "default": 0
                        },
                        "currentPage": {
                          "type": "integer",
                          "example": 1,
                          "default": 0
                        }
                      }
                    }
                  }
                }
              }
            }
          }
        },
        "deprecated": false
      }
    }
  },
  "x-readme": {
    "headers": [],
    "explorer-enabled": false,
    "proxy-enabled": true
  },
  "x-readme-fauxas": true,
  "_id": "65f06b6583c5de0051b8aa08:65f06b6583c5de0051b8aa18"
}
```

/transactions/:id

# /transactions/:id

Retrieve information about a specific transaction

Response Schema:

```json
{
    "status": boolean,
    "message": string,
    "data": {
        "id": string,
        "amount": string,
        "currency": string,
        "narration": string,
        "type": "credit" | "debit",
        "datetime": date-time,
        "accountId": string,
        "balance": string | null
    }
}
```

# OpenAPI definition

```json
{
  "openapi": "3.1.0",
  "info": {
    "title": "Lenco API",
    "version": "2.0"
  },
  "servers": [
    {
      "url": "https://api.lenco.co/access/v2"
    }
  ],
  "components": {
    "securitySchemes": {
      "sec0": {
        "type": "apiKey",
        "in": "header",
        "name": "Authorization",
        "x-bearer-format": "bearer",
        "x-default": "xo+CAiijrIy9XvZCYyhjrv0fpSAL6CfU8CgA+up1NXqK"
      }
    }
  },
  "security": [
    {
      "sec0": []
    }
  ],
  "paths": {
    "/transactions/{id}": {
      "get": {
        "summary": "/transactions/:id",
        "description": "Retrieve information about a specific transaction",
        "operationId": "get-transaction-by-id",
        "parameters": [
          {
            "name": "id",
            "in": "path",
            "description": "Your 36-character transaction uuid",
            "schema": {
              "type": "string"
            },
            "required": true
          }
        ],
        "responses": {
          "200": {
            "description": "200",
            "content": {
              "application/json": {
                "examples": {
                  "Result": {
                    "value": "{\n    \"status\": true,\n    \"message\": \"\",\n    \"data\": {\n        \"id\": \"d6730fe6-77a0-4432-a283-832eaef31786\",\n        \"amount\": \"13.00\",\n        \"currency\": \"ZMW\",\n        \"narration\": \"Transfer / 240730006\",\n        \"type\": \"debit\",\n        \"datetime\": \"2024-01-10T14:24:31.931Z\",\n        \"accountId\": \"b176cda5-7d97-4a3f-b4dd-ab0234e9e08c\",\n        \"balance\": \"997559.00\"\n      }\n}"
                  }
                },
                "schema": {
                  "type": "object",
                  "properties": {
                    "status": {
                      "type": "boolean",
                      "example": true,
                      "default": true
                    },
                    "message": {
                      "type": "string",
                      "example": ""
                    },
                    "data": {
                      "type": "object",
                      "properties": {
                        "id": {
                          "type": "string",
                          "example": "d6730fe6-77a0-4432-a283-832eaef31786"
                        },
                        "amount": {
                          "type": "string",
                          "example": "13.00"
                        },
                        "currency": {
                          "type": "string",
                          "example": "ZMW"
                        },
                        "narration": {
                          "type": "string",
                          "example": "Transfer / 240730006"
                        },
                        "type": {
                          "type": "string",
                          "example": "debit"
                        },
                        "datetime": {
                          "type": "string",
                          "example": "2024-01-10T14:24:31.931Z"
                        },
                        "accountId": {
                          "type": "string",
                          "example": "b176cda5-7d97-4a3f-b4dd-ab0234e9e08c"
                        },
                        "balance": {
                          "type": "string",
                          "example": "997559.00"
                        }
                      }
                    }
                  }
                }
              }
            }
          },
          "404": {
            "description": "404",
            "content": {
              "application/json": {
                "examples": {
                  "Result": {
                    "value": "{\n    \"status\": false,\n    \"message\": \"Transaction was not found\",\n    \"data\": null\n}"
                  }
                },
                "schema": {
                  "type": "object",
                  "properties": {
                    "status": {
                      "type": "boolean",
                      "example": false,
                      "default": true
                    },
                    "message": {
                      "type": "string",
                      "example": "Transaction was not found"
                    },
                    "data": {}
                  }
                }
              }
            }
          }
        },
        "deprecated": false
      }
    }
  },
  "x-readme": {
    "headers": [],
    "explorer-enabled": false,
    "proxy-enabled": true
  },
  "x-readme-fauxas": true,
  "_id": "65f06b6583c5de0051b8aa08:65f06b6583c5de0051b8aa19"
}
```

Webhooks

# Webhooks

Learn how to listen to events whenever certain actions occur on your integration.

## What are webhooks?

Whenever certain actions occur on your Lenco account or API integration, we trigger events which your application can listen to. This is where webhooks come in. A webhook is a URL on your server where we send payloads for such events. For example, if you implement webhooks, once a transfer is successful, we will immediately notify your server with a `transfer.successful` event. Here is a [list of events](#types-of-events) we can send to your webhook URL.

> 📘
>
> **NB**: You may not be able to rely completely on webhooks to get notified. An example is if your server is experiencing a downtime and your hook endpoints are affected, some customers might still be transacting independently of that and the hook call triggered would fail because your server was unreachable.
>
> *In such cases we advise that developers set up a re-query service that goes to poll for the transaction status at regular intervals e.g. every 30 minutes using the `/transfers/:id` or `/transfers/status/:reference` endpoint, till a successful or failed response is returned.*

To setup your webhook URL, kindly reach out to <support@lenco.co>

**Here are some things to note when setting up a webhook URL:**

1. If using .htaccess, remember to add the trailing / to the url you set.
2. Do a test post to your URL and ensure the script gets the post body.
3. Ensure your webhook URL is publicly available (localhost URLs cannot receive events)

## Receiving an event

All you have to do to receive the event is to create an unauthenticated POST route on your application. The event object is sent as JSON in the request body.

```javascript Node
// Using Express
app.post("/my/webhook/url", function(req, res) {
    // Retrieve the request's body
    var event = req.body;
    // Do something with event
    res.send(200);
});
```
```php
<?php
// Retrieve the request's body and parse it as JSON
$input = @file_get_contents("php://input");
$event = json_decode($input);
// Do something with $event
http_response_code(200); // PHP 5.4 or greater
?>
```

## Verifying events

It is important to verify that events originate from Lenco to avoid delivering value based on a counterfeit event.\
Valid events are raised with an header `X-Lenco-Signature` which is essentially a HMAC SHA512 signature of the event payload signed using your `webhook_hash_key`.\
The `webhook_hash_key` is a SHA256 hash of your API token.

```javascript Node
var crypto = require('crypto');
var apiToken = process.env.API_TOKEN;
var webhookHashKey = crypto.createHash("sha256").update(apiToken).digest("hex");
// Using Express
app.post("/my/webhook/url", function(req, res) {
    //validate event
    var hash = crypto.createHmac('sha512', webhookHashKey).update(JSON.stringify(req.body)).digest('hex');
    if (hash === req.headers['x-lenco-signature']) {
        // Retrieve the request's body
        var event = req.body;
        // Do something with event  
    }
    res.send(200);
});
```
```php
<?php
// only a post with lenco signature header gets our attention
if ((strtoupper($_SERVER['REQUEST_METHOD']) != 'POST' ) || !array_key_exists('HTTP_X_LENCO_SIGNATURE', $_SERVER) ) 
    exit();
// Retrieve the request's body
$input = @file_get_contents("php://input");
define('LENCO_API_TOKEN','API_TOKEN');
$webhook_hash_key = hash("sha256", LENCO_API_TOKEN);
// validate event do all at once to avoid timing attack
if($_SERVER['HTTP_X_LENCO_SIGNATURE'] !== hash_hmac('sha512', $input, $webhook_hash_key))
    exit();
http_response_code(200);
// parse event (which is json string) as object
// Do something - that will not take long - with $event
$event = json_decode($input);
exit();
?>
```

## Responding to an event

You should respond to an event with a `200` OK. We consider this an acknowledgement by your application. If your application responds with any status outside of either `200`, `201`, or `202`, we will consider it unacknowledged and thus, continue to send it every 30 minutes for 24 hours. You don't need to send a request body or some other parameter as it would be discarded - we only pay attention to the status code.

If your application is likely to start a long running task in response to the event, Lenco may timeout waiting for the response and would ultimately consider the event unacknowledged and queue to be raised later. You can mitigate duplicity by having your application respond immediately with a 200 before it goes on to perform the rest of the task.

## Types of events

Here are the events we currently raise. We would add more to this list as we hook into more actions in the future.

| Event                   | Description                                                                             |
| :---------------------- | :-------------------------------------------------------------------------------------- |
| `transfer.successful`   | A transfer was successfully completed from any of the accounts linked to your API token |
| `transfer.failed`       | A transfer you attempted from any of the accounts linked to your API token has failed   |
| `collection.successful` | A collection you attempted was successfully completed                                   |
| `collection.failed`     | A collection you attempted has failed                                                   |
| `collection.settled`    | Your account was credited for a collection                                              |
| `transaction.credit`    | An account linked to your API token was credited                                        |
| `transaction.debit`     | An account linked to your API token was debited                                         |

```json transfer.successful
{
    "event": "transfer.successful",
    "data": {
        "id": string,
        "amount": string,
        "fee": string,
        "currency": string,
        "narration": string,
        "initiatedAt": date-time,
        "completedAt": date-time | null,
        "accountId": string,
        "creditAccount": {
            "id": string | null,
            "type": string,
            "accountName": string,
            "accountNumber": string | null,
            "bank": {
                "id": string,
                "name": string,
                "country": string
            } | null,
            "phone": string | null,
            "operator": string | null,
            "walletNumber": string | null,
            "tillNumber": string | null
        },
        "status": "pending" | "successful" | "failed",
        "reasonForFailure": string | null,
        "reference": string | null,
        "lencoReference": string,
        "extraData": {
            "nipSessionId": string | null,
        },
        "source": "banking-app" | "api"
    }
}
```
```json transfer.failed
{
    "event": "transfer.failed",
    "data": {
        "id": string,
        "amount": string,
        "fee": string,
        "currency": string,
        "narration": string,
        "initiatedAt": date-time,
        "completedAt": date-time | null,
        "accountId": string,
        "creditAccount": {
            "id": string | null,
            "type": string,
            "accountName": string,
            "accountNumber": string | null,
            "bank": {
                "id": string,
                "name": string,
                "country": string
            } | null,
            "phone": string | null,
            "operator": string | null,
            "walletNumber": string | null,
            "tillNumber": string | null
        },
        "status": "pending" | "successful" | "failed",
        "reasonForFailure": string | null,
        "reference": string | null,
        "lencoReference": string,
        "extraData": {
            "nipSessionId": string | null,
        },
        "source": "banking-app" | "api"
    }
}
```
```json collection.successful
{
    "event": "collection.successful",
    "data": {
        "id": string,
        "initiatedAt": date-time,
        "completedAt": date-time | null,
        "amount": string,
        "fee": string | null,
        "bearer": "merchant" | "customer",
        "currency": string,
        "reference": string | null,
        "lencoReference": string,
        "type": "card" | "mobile-money" | "bank-account" | null,
        "status": "pending" | "successful" | "failed" | "pay-offline",
        "source": "banking-app" | "api",
        "reasonForFailure": string | null,
        "settlementStatus": "pending" | "settled" | null,
        "settlement": {
            "id": string,
            "amountSettled": string,
            "currency": string,
            "createdAt": date-time,
            "settledAt": date-time | null,
            "status": "pending" | "settled",
            "type": "instant" | "next-day",
            "accountId": string,
        } | null,
        "mobileMoneyDetails": {
            "country": string,
            "phone": string,
            "operator": string,
            "accountName": string | null,
            "operatorTransactionId": string | null,
        } | null,
        "bankAccountDetails": null,
        "cardDetails": null,
    }
}
```
```json collection.failed
{
    "event": "collection.failed",
    "data": {
        "id": string,
        "initiatedAt": date-time,
        "completedAt": date-time | null,
        "amount": string,
        "fee": string | null,
        "bearer": "merchant" | "customer",
        "currency": string,
        "reference": string | null,
        "lencoReference": string,
        "type": "card" | "mobile-money" | "bank-account" | null,
        "status": "pending" | "successful" | "failed" | "pay-offline",
        "source": "banking-app" | "api",
        "reasonForFailure": string | null,
        "settlementStatus": "pending" | "settled" | null,
        "settlement": {
            "id": string,
            "amountSettled": string,
            "currency": string,
            "createdAt": date-time,
            "settledAt": date-time | null,
            "status": "pending" | "settled",
            "type": "instant" | "next-day",
            "accountId": string,
        } | null,
        "mobileMoneyDetails": {
            "country": string,
            "phone": string,
            "operator": string,
            "accountName": string | null,
            "operatorTransactionId": string | null,
        } | null,
        "bankAccountDetails": null,
        "cardDetails": null,
    }
}
```
```json collection.settled
{
    "event": "collection.settled",
    "data": {
        "id": string,
        "initiatedAt": date-time,
        "completedAt": date-time | null,
        "amount": string,
        "fee": string | null,
        "bearer": "merchant" | "customer",
        "currency": string,
        "reference": string | null,
        "lencoReference": string,
        "type": "card" | "mobile-money" | "bank-account" | null,
        "status": "pending" | "successful" | "failed" | "pay-offline",
        "source": "banking-app" | "api",
        "reasonForFailure": string | null,
        "settlementStatus": "pending" | "settled" | null,
        "settlement": {
            "id": string,
            "amountSettled": string,
            "currency": string,
            "createdAt": date-time,
            "settledAt": date-time | null,
            "status": "pending" | "settled",
            "type": "instant" | "next-day",
            "accountId": string,
        } | null,
        "mobileMoneyDetails": {
            "country": string,
            "phone": string,
            "operator": string,
            "accountName": string | null,
            "operatorTransactionId": string | null,
        } | null,
        "bankAccountDetails": null,
        "cardDetails": null,
    }
}
```
```json transaction.credit
{
    "event": "transaction.credit",
    "data": {
        "id": string,
        "amount": string,
        "currency": string,
        "narration": string,
        "type": "credit" | "debit",
        "datetime": date-time,
        "accountId": string,
        "balance": string | null
    }
}
```
```json transaction.debit
{
    "event": "transaction.debit",
    "data": {
        "id": string,
        "amount": string,
        "currency": string,
        "narration": string,
        "type": "credit" | "debit",
        "datetime": date-time,
        "accountId": string,
        "balance": string | null
    }
}
```

Encryption

# Encryption

The transport between client applications and Lenco is secured using TLS/SSL, which means data is encrypted by default when transmitted across networks.

In addition, certain endpoints of the Lenco API make use of JSON Web Encryption (JWE) to provide end-to-end payload encryption to secure sensitive data. For instance, the [Card Collection API](https://lenco-api.readme.io/v2.0/reference/initiate-collection-from-card) must comply with the Payment Card Industry Data Security Standard in dealing with cardholder Personally Identifying Information (PII).

JSON Web Encryption (JWE) represents encrypted content using JSON-based data structures and base64url encoding. Lenco uses JWE compact serialization for the encryption of sensitive data.

Lenco encryption uses AES in GCM (Galois/Counter Mode) mode with PKCS#7 padding and RSA with OAEP (Optimal Asymmetric Encryption Padding).

<br />

### The Encryption Keys

**RSA**\
Encryption involves a 2048-bit RSA public/private key pair. Data encrypted using a public key can only be decrypted using the corresponding private key.

The client application will get an RSA public key using the [Get Encryption Key](https://lenco-api.readme.io/v2.0/reference/get-encryption-key) endpoint, which allows to encrypt the request payload.

**AES**\
For performance reasons, RSA asymmetric encryption is combined with AES symmetric encryption. For that, a one-time usage 256-bit AES session key is generated and encrypted using the RSA public key. The encrypted (or wrapped) key is sent in the payload along with the encrypted data.

<br />

### The Encryption Process

Here are the steps for sending an encrypted payload:

1. An AES session key is generated along with some encryption parameters
2. Sensitive data are encrypted using the AES key
3. The AES key is encrypted using the RSA public key gotten from the [Get Encryption Key](https://lenco-api.readme.io/v2.0/reference/get-encryption-key) endpoint
4. The payload is sent with the encrypted session key and parameters

<br />

### How to Encrypt Payload

The encrypted payload is structured in JSON Web Encryption (JWE) format, the plain text JSON body is encrypted to form a JWE encrypted payload that is sent as the request body (replacing the plain text data).

**Step 1**: Construct the original JSON per the API specification.

**Step 2**: Get the RSA public key using from the [Get Encryption Key](https://lenco-api.readme.io/v2.0/reference/get-encryption-key) endpoint. Beware that this key might change anytime and therefore should not be stored and reused.

**Step 3**: Use JWE to encrypt the original request in compact serialized form using the below JOSE headers:

| JOSE Header | Value                                      | Description                                                                                   |
| :---------- | :----------------------------------------- | :-------------------------------------------------------------------------------------------- |
| enc         | A256GCM                                    | encryption algorithm                                                                          |
| alg         | RSA-OAEP-256                               | Key encryption algorithm                                                                      |
| cty         | application/json                           | content type of the encrypted payload                                                         |
| kid         | `kid` property of the RSA public key (JWK) | Public Fingerprint ID which is used to identify the private key needed to decrypt the message |

**Step 4**: Construct request payload as shown below:

```json
{
    "encryptedPayload": "JWE encrypted payload"
}
```

<br />

Examples:

```go
package main

import (
    "github.com/lestrrat-go/jwx/jwa"
    "github.com/lestrrat-go/jwx/jwe"
    "github.com/lestrrat-go/jwx/jwk"
)

func encrypt(payload []byte) (string, error) {
    jwkJSON := `{
        "kty": "RSA",
        "use": "enc",
        "n": "nApb8LyyFrZw4A(...)W1RpGR6Z7zcNikiZcQ",
        "e": "AQAB",
        "kid": "2bbb0d(...)2f68aa"
    }`

    rsaPublicKey, err := jwk.ParseKey([]byte(jwkJSON))
    if err != nil {
        return "", err
    }

    encrypted, err := jwe.Encrypt(payload, jwa.RSA_OAEP_256, rsaPublicKey, jwa.A256GCM, jwa.NoCompress)
    if err != nil {
        return "", err
    }

    return string(encrypted[:]), nil
}
```
```node
const jose = require("jose");

async function encrypt(payload) {
    const jwkData = {
        "kty": "RSA",
        "use": "enc",
        "n": "nApb8LyyFrZw4A(...)W1RpGR6Z7zcNikiZcQ",
        "e": "AQAB",
        "kid": "2bbb0d(...)2f68aa"
    };

    const rsaPublicKey = await jose.importJWK(jwkData);
    const text = JSON.stringify(payload);
    const jwe = await new jose.CompactEncrypt(new TextEncoder().encode(text))
        .setProtectedHeader({
            alg: 'RSA-OAEP-256',
            enc: 'A256GCM',
            cty: 'application/json',
            kid: jwkData.kid
        })
        .encrypt(rsaPublicKey);

    return jwe;
}
```

> 🚧 NB
>
> The examples above are just code samples to help get you started. Lenco does not in any way recommend the use of these libraries.\
> It is important that you scrutinise / audit any third party library or package before using it in production.


/encryption-key

# /encryption-key

Get RSA public key to [encrypt a request payload](https://lenco-api.readme.io/v2.0/reference/encryption)

This endpoint returns the RSA public key in [JWK](https://datatracker.ietf.org/doc/html/rfc7517) format.

# OpenAPI definition

```json
{
  "openapi": "3.1.0",
  "info": {
    "title": "Lenco API",
    "version": "2.0"
  },
  "servers": [
    {
      "url": "https://api.lenco.co/access/v2"
    }
  ],
  "components": {
    "securitySchemes": {
      "sec0": {
        "type": "apiKey",
        "in": "header",
        "name": "Authorization",
        "x-bearer-format": "bearer",
        "x-default": "xo+CAiijrIy9XvZCYyhjrv0fpSAL6CfU8CgA+up1NXqK"
      }
    }
  },
  "security": [
    {
      "sec0": []
    }
  ],
  "paths": {
    "/encryption-key": {
      "get": {
        "summary": "/encryption-key",
        "description": "Get RSA public key to [encrypt a request payload](https://lenco-api.readme.io/v2.0/reference/encryption)",
        "operationId": "get-encryption-key",
        "responses": {
          "200": {
            "description": "200",
            "content": {
              "application/json": {
                "examples": {
                  "Result": {
                    "value": "{\n    \"status\": true,\n    \"message\": \"\",\n    \"data\": {\n        \"kty\": \"RSA\",\n        \"use\": \"enc\",\n        \"n\": \"nApb8LyyFrZw4A(...)W1RpGR6Z7zcNikiZcQ\",\n        \"e\": \"AQAB\",\n        \"kid\": \"2bbb0d(...)2f68aa\"\n    }\n}"
                  }
                },
                "schema": {
                  "type": "object",
                  "properties": {
                    "status": {
                      "type": "boolean",
                      "example": true,
                      "default": true
                    },
                    "message": {
                      "type": "string",
                      "example": ""
                    },
                    "data": {
                      "type": "object",
                      "properties": {
                        "kty": {
                          "type": "string",
                          "example": "RSA"
                        },
                        "use": {
                          "type": "string",
                          "example": "enc"
                        },
                        "n": {
                          "type": "string",
                          "example": "nApb8LyyFrZw4A(...)W1RpGR6Z7zcNikiZcQ"
                        },
                        "e": {
                          "type": "string",
                          "example": "AQAB"
                        },
                        "kid": {
                          "type": "string",
                          "example": "2bbb0d(...)2f68aa"
                        }
                      }
                    }
                  }
                }
              }
            }
          }
        },
        "deprecated": false
      }
    }
  },
  "x-readme": {
    "headers": [],
    "explorer-enabled": false,
    "proxy-enabled": true
  },
  "x-readme-fauxas": true,
  "_id": "65f06b6583c5de0051b8aa08:6711299a85c2110012b959e6"
}
```