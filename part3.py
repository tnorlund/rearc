#!/usr/bin/env python3
import os
import json
import boto3
import pandas as pd
from io import StringIO

def lambda_handler(event, context):

  # In[106]:


  s3 = boto3.client('s3')


  # Load both the csv file from **Part 1** `pr.data.0.Current` and the json file from **Part 2**

  # In[107]:


  obj = s3.get_object( 
      Bucket=os.environ['BucketName'],
      Key="pr.data.0.Current"
  )
  StringData = StringIO(obj['Body'].read().decode('utf-8'))
  df_part_1 = pd.read_csv(StringData, sep="\t")
  df_part_1.rename(
      columns = {
          old_name:old_name.strip().title()
          for old_name in df_part_1.columns.tolist()
      }, 
      inplace = True
  )


  # In[108]:


  obj = s3.get_object( 
      Bucket=os.environ['BucketName'],
      Key="api.json"
  )
  j = json.loads(obj['Body'].read())
  df_part_2 = pd.DataFrame.from_records(j['data'])
  df_part_2['Year'] = pd.to_numeric(df_part_2['Year'])


  # Using the dataframe from the population data API **Part 2**, generate the mean and the standard deviation of the US population across the years [2013, 2018] inclusive.
  # 
  # **Answer**

  # In[109]:


  print(df_part_2)


  # The folks at datausa are currently having issues with their API:
  # ![Broken API](BrokenAPI.png)
  # 
  # I was able to get a payload from the base slug in the README. It's the dataframe above this cell. I won't be able to "generate the mean and the standard deviation" since I have no idea how to get more granular with this API. 🙄

  # Using the dataframe from the time-series (Part 1), For every series_id, find the *best year*: the year with the max/largest sum of "value" for all quarters in that year. Generate a report with each series id, the best year for that series, and the summed value for that year.
  # 
  # **Answer**
  # 
  # After grouping by the `"Series_Id"` and `"Year"`, we sum the values. This gives us the "total" value per `"Series_Id"` and `"Year"`. The pandas series is then reduced to a dataframe. The new dataframe is then indexed by the largest value per `"Year"`.

  # In[142]:


  df = df_part_1.groupby(
      ["Series_Id", "Year"]
  )["Value"].sum().reset_index(
      level = [0 , 1]
  )
  print(df.loc[df.groupby('Series_Id')['Value'].idxmax()])


  # Using both dataframes from Part 1 and Part 2, generate a report that will provide the `value` for `series_id = PRS30006032` and `period = Q01` and the `population` for that given year (if available in the population dataset)
  # 
  # **Answer**
  # 
  # Based on how the question is written, I'm assuming that you want join the 2 dataframes together. Here, I've joined the dataframes through a `'right'` join. This means that each year in part 1 is joined with each year in part 2. If the year isn't in part 2, it's not in this dataframe.

  # In[104]:


  print(df_part_1.merge(df_part_2, on='Year', how='right'))

