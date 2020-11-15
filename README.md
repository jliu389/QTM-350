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

```
import pandas as pd
```

Then, we use the `read_json()` function in pandas to transform our filtered JSON into a *dataframe*.

```
pd.read_json('facebook-app-review1.json', orient='records')
```

Let's save the dataframe as a Python variable, which we will call `df1`, so that we can use it for more purposes than just viewing.

```
df1=pd.read_json('facebook-app-review1.json', orient='records')
df1=df1[['review']]
```

A dataframe consists of a *header*, where you find the names of the *columns*, *rows* where you find the values in those columns, and an *index* where you can find the row number. So this includes the information you find in a csv. Indeed, we can write this to a .csv file with the following pandas function.

```
df1.to_csv('facebook-app-review1.csv')
```

# Store Data into S3

### Set up an IAM Role
In order to use this API within Sagemaker, we will need to update the Role we have been using to control Sagemaker permissions.

#### Where can I find that role?
Go to your Sagemaker dashboard, then notebook instances, then click the notebook instance name to access the page for the "Notebook instance settings". You should then see the page below.

![Notebook instance settings](./Permission.png)


There, under the heading "Permissions and encryption" click the link to the IAM role ARN. You should then see a view similar to this one below.


![Notebook instance settings](./IAM.png) 

#### Adding policies
As we work with new AWS services within our notebooks, it will be necessary to add policies which give Sagemaker access to them. To use the examples we will present for working with Amazon Comprehend, you will need to add `ComprehendFullAccess` permissions.

To add them, in the IAM role Summary page (pictured in the last screenshot), click the blue "Attach policies" button. In the search bar, type the names of these services that were just listed, select them by ticking the empty white box next to the name when it appears, and then click the blue "Attach policy" button. 

`AdministratorAccess` also needs to be added for creating IAM Role for Amazon Comprehend later on.

### Getting started using the console
Before using the Comprehend service programatically, it will be helpful to understand what it does by walking through examples in the AWS console [here](https://console.aws.amazon.com/comprehend/home?region=us-east-1#home).

### Working with the Comprehend API programatically
In this section, you use the Amazon Comprehend API operations to analyze text.

### Set up the AWS CLI
In any new Sagemaker instance, the AWS CLI (Command Line Interface) comes preinstalled. Indeed, to check that this is the case, run the command below.

```
!aws s3 help
```

Next, let's create a S3 bucket called `sentiment-review-facebook`.

```
!aws s3 mb s3://sentiment-review-facebook
```

To ensure that your bucket was created successfully, run the following command.

```
!aws s3 ls
```

### Upload Input Data
By adding the path /input/ at the end, Amazon S3 automatically creates a new folder called input in your bucket and uploads the dataset file to that folder.

```
!aws s3 cp facebook-app-review1.csv s3://sentiment-review-facebook/input/
```

To ensure that your file was uploaded successfully, run the following command. The command lists the contents of your bucket's `input` folder.

```
!aws s3 ls sentiment-review-facebook/input/
```

# Creating IAM Role for Amazon Comprehend
### To Create IAM Role

Save the following trust policy as a JSON document called `comprehend-trust-policy.json` in a code or text editor. This trust policy declares Amazon Comprehend as a trusted entity and allows it to assume an IAM role.

{
  "Version": "2012-10-17",  
  "Statement": [  
    
    {    
      "Effect": "Allow",      
      "Principal": {      
        "Service": "comprehend.amazonaws.com"        
      },      
      "Action": "sts:AssumeRole"      
    }
  ]  
}

To create the IAM role, run the following AWS CLI command. The command creates an IAM role called comprehend-access-role and attaches the trust policy to the role.

```
!aws iam create-role --role-name comprehend-access-role --assume-role-policy-document file:///home/ec2-user/SageMaker/comprehend-trust-policy.json
```

Copy the Amazon Resource Name (ARN) and save it in a text editor. You need this ARN to run Amazon Comprehend analysis jobs.

### To Create IAM Policy

Save the following policy locally as a JSON document called `comprehend-access-policy.json`. It grants Amazon Comprehend access to the specified S3 bucket.

{    
    "Version": "2012-10-17",
    "Statement": [
        {
            "Action": [
                "s3:GetObject"
            ],
            "Resource": [
                "arn:aws:s3:::DOC-EXAMPLE-BUCKET/*"
            ],
            "Effect": "Allow"
        },
        {
            "Action": [
                "s3:ListBucket"
            ],
            "Resource": [
                "arn:aws:s3:::DOC-EXAMPLE-BUCKET"
            ],
            "Effect": "Allow"
        },
        {
            "Action": [
                "s3:PutObject"
            ],
            "Resource": [
                "arn:aws:s3:::DOC-EXAMPLE-BUCKET/*"
            ],
            "Effect": "Allow"
        }
    ]
}

To create the S3 bucket access policy, run the following AWS CLI command.

```
!aws iam create-policy --policy-name comprehend-access-policy1 --policy-document file:///home/ec2-user/SageMaker/comprehend-access-policy.json
```

Copy the access policy ARN and save it in a text editor.
You need this ARN to attach your access policy to your IAM role.

### To Attach IAM Policy IAM Role

```
!aws iam attach-role-policy --policy-arn arn:aws:iam::823422836579:policy/comprehend-access-policy1 --role-name comprehend-access-role
```

You now have an IAM role called `comprehend-access-role` that has a trust policy for Amazon Comprehend and an access policy that grants Amazon Comprehend access to your S3 bucket. 

# Running AWS Comprehend Analysis

```
!aws comprehend start-sentiment-detection-job --input-data-config S3Uri=s3://sentiment-review-facebook/input/ --output-data-config S3Uri=s3://sentiment-review-facebook/output/ --data-access-role-arn arn:aws:iam::823422836579:role/comprehend-access-role --job-name reviews-sentiment-analysis --language-code en --region us-east-1 
```

After you submit the job, copy the `JobId` and save it to a text editor. You will need the JobId to find the output files from the analysis job.

```
!aws comprehend describe-sentiment-detection-job --job-id c3c37495ed423dc20eabae704a151ab9
```

# Preparing the Output
### Download Output Files

In the OutputDataConfig object, find the `S3Uri` value. And download the sentiment output archive to your local directory.

```
!aws s3 cp s3://sentiment-review-facebook/output/823422836579-SENTIMENT-c3c37495ed423dc20eabae704a151ab9/output/output.tar.gz /home/ec2-user/SageMaker/sentiment-output.tar.gz
```

### Extract Output Files

```
!tar -xvf sentiment-output.tar.gz --transform 's,^,sentiment-,'
```

### Upload Output Files to S3

```
!aws s3 cp /home/ec2-user/SageMaker/sentiment-output s3://sentiment-review-facebook/sentiment-results/
```

### To load the data into an AWS Glue Data Catalog

To create an IAM role for AWS Glue, save the following trust policy as a JSON document called `glue-trust-policy.json`.

{
  "Version": "2012-10-17",
  "Statement": [
  
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "glue.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}

```
!aws iam create-role --role-name glue-access-role --assume-role-policy-document file:///home/ec2-user/SageMaker/glue-trust-policy.json
```

Save Amazon Resource Number (ARN) for the new role.

Save the following IAM policy as a JSON document called `glue-access-policy.json`. The policy grants AWS Glue permission to crawl your results folders.

{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "s3:GetObject",
                "s3:PutObject"
            ],
            "Resource": [
                "arn:aws:s3:::DOC-EXAMPLE-BUCKET/sentiment-results*"
            ]
        }
    ]
}

```
!aws iam create-policy --policy-name glue-access-policy --policy-document file:///home/ec2-user/SageMaker/glue-access-policy.json
```

Save ARN again and attach the new policy to the IAM role.

```
!aws iam attach-role-policy --policy-arn arn:aws:iam::823422836579:policy/glue-access-policy --role-name glue-access-role
```

Attach the AWS managed policy AWSGlueServiceRole to your IAM role by running the following command.

```
!aws iam attach-role-policy --policy-arn arn:aws:iam::aws:policy/service-role/AWSGlueServiceRole --role-name glue-access-role
```

Create an AWS Glue database by running the following command.

```
!aws glue create-database --database-input Name="comprehend-results"
```

Create a new AWS Glue crawler.

```
!aws glue create-crawler --name comprehend-analysis-crawler --role arn:aws:iam::823422836579:role/glue-access-role  --targets S3Targets=[{Path="s3://sentiment-review-facebook/sentiment-results"}] --database-name comprehend-results
```

Start the crawler.

```
!aws glue start-crawler --name comprehend-analysis-crawler
```

### Prepare the Data for Analysis

Now you have a database populated with the Amazon Comprehend results. However, the results are nested. To unnest them, you run a few SQL statements in Amazon Athena. Amazon Athena is an interactive query service that makes it easy to analyze data in Amazon S3 using standard SQL. Athena is serverless, so there is no infrastructure to manage and it has a pay-per-query pricing model. In this step, you create new tables of cleaned data that you can use for analysis and visualization. You use the Athena console to prepare the data.

Open the [Athena console](https://console.aws.amazon.com/athena/).

In the navigation bar, choose Settings.

For Query result location, enter s3://DOC-EXAMPLE-BUCKET/query-results/. This creates a new folder called query-results in your bucket that stores the output of the Amazon Athena queries you run. Choose Save.

In the navigation bar, choose Query editor.

For Database, choose the AWS Glue database `comprehend-results` that you created.

In the Tables section, you should have one table called sentiment_results. Preview the table to make sure that the crawler loaded the data. In table’s options, choose Preview table. A short query runs automatically. Check the Results pane to ensure that the table contain data.

To unnest the `sentiment_results table`, enter the following query in the **Query editor** and choose **Run query**.

*CREATE TABLE sentiment_results_final AS*

*SELECT file, line, sentiment,*

*sentimentscore.mixed AS mixed,*

*sentimentscore.negative AS negative,*

*sentimentscore.neutral AS neutral,*

*sentimentscore.positive AS positive*

*FROM sentiment_results*

After obtaining the results from Athena, download the csv file.

```
df1=pd.read_csv('facebook-app-review1.csv')
df2=pd.read_csv('sentiment-output-final.csv')
df1.columns =['line', 'rating', 'review'] 
final_dataset=pd.merge(df1, df2)
final_dataset=final_dataset[['review', 'sentiment', 'mixed', 'negative', 'neutral', 'positive']]
final_dataset.to_csv('final_dataset.csv')
```
