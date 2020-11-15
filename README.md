# Amazon Comprehend Project


## Retrieving API Data
### Getting API and Access Token
**42matters** provides App Reviews API for Apple App Store iOS Apps. We can get information such as dates, ratings of the app, and review contents. From [here](https://42matters.com/docs/app-market-data/ios/apps/reviews), you can sign up for free and get an access token on a 14-day trial. 

![Notebook instance settings](./App-Reviews-API.png)

#### API key and `getpass`
Below, we are using a python package called getpass. On the first line of the code cell below, `import getpass` will load all of the functions that are available in the getpass package into memory on our notebook's machine. 

Then, we use the function `getpass()` by referring to where it is located with `getpass.getpass()` and storing the output of that function in a variable we are calling `APIKEY`.

```
import getpass
APIKEY = getpass.getpass()
```

### Saving and filtering the results of a API call
The output is in json format, but it is really hard to read. Let's save it to another file. Then we will use another tool to filter the json file down to the information we are interested in.
#### Saving output
To save the output, we add another argument to the curl command, `-o`, and then after it, we write a name for the file.

```
!curl --request GET -o facebook-app-review01.json "https://data.42matters.com/api/v2.0/ios/apps/reviews.json?id=284882215&access_token=$APIKEY&days=30&limit=100&lang=en"
```

### Viewing and filtering the JSON with `jq`
[`jq`](https://stedolan.github.io/jq/)is a command line tool for  slicing, filtering, transforming JSON data. 

First we install it with the cell below.

```
!sudo yum install jq
!jq < facebook-app-review01.json
```

### Filtering using `jq`
To filter based on key, use `jq '.key'`, where `.key` is one of the keys from the JSON file, and `jq` will return the corresponding values in the JSON. For example, we filter on the key `reviews` in the cell below for Facebook App Reviews.

```
!jq '.reviews' < facebook-app-review01.json
```

Let's dig deeper and look at the values for the key `content`. Since it is within the values of the key `reviews`, we will use  `.reviews[].content` to filter out the review contents. 

```
!jq 'reviews[].content ' < facebook-app-review01.json  >facebook-app-review1.json
```

### From JSON to csv
For working with structured data in notebooks, the most popular and full-featured packages is `pandas`.  It can tranform our JSON into a csv file.

First we import the pandas package.
