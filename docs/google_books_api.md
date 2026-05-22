## Note on Global reviews retrieved from Google Books API

It was discovered that the Global review feature present when reviewing was showing "Global rating not available" and this was due to the following rate limiting error (produced when running locally).

```
Quota exceeded for quota metric 'Queries' and limit 'Queries per day' of service 'books.googleapis.com' for consumer 'project_number:624717413613'.
```

To overcome this, a Google Cloud API key was added:

1. https://console.cloud.google.com/ → Project shelfd
2. Navigation Menu → APIs and services → Library → Books API (Enable)
3. Navigation Menu → APIs and services → Credential → Create credentials → API key

This API key:
- Is restricted to solely the Books API (No access to other Google Services)
- Stored within the project "shelfd"
- Provides quota of 1,000 requests/day
- Is free, no billing associated with Books API

> [!NOTE]
> The API Key is present in the code hardcoded. The security risk should be minimal due to the restricted access this key has (e.g. Books API) 
