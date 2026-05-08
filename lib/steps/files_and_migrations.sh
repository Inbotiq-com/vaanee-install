azureuser@vaanee-test-new:~/vaanee$ curl -s -X POST "https://vaanee-test.inbotiq.ai/api/auth/login" \
  -H "Content-Type: application/json" \         
  -d '{"email":"dixeli9168@muncloud.com","password":"Testing@123"}'
{"error":"Vaanee main server not configured for authentication"}azureuser@vaanee-test-new:~/vaanee$ curl -s -X POST azureuser@vaanee-test-new:~/vaanee$ # 1) backend response body dekh lo
curl -s -X POST "https://vaanee-test.inbotiq.ai/api/auth/login" \
  -H "Content-Type: application/json" \
  -d '{"email":"darshan@inbotiq.com","password":"Testing@123"}'
{"error":"Vaanee main server not configured for authentication"}azureuser@vaanee-test-new:~/vaanee$ # 2) DB me auth azureuser@vaanee-test-new:~/vaanee$ psql "$DATABASE_URL" -c "\dt" | egrep "users|admins|organizations"
psql: error: connection to server on socket "/var/run/postgresql/.s.PGSQL.5432" failed: No such file or directory
        Is the server running locally and accepting connections on that socket?
azureuser@vaanee-test-new:~/vaanee$ # 3) agar tables hain to rows check karo
psql "$DATABASE_URL" -c "select count(*) from users;"
psql "$DATABASE_URL" -c "select count(*) from admins;"
psql "$DATABASE_URL" -c "select count(*) from organizations;"
psql: error: connection to server on socket "/var/run/postgresql/.s.PGSQL.5432" failed: No such file or directory
        Is the server running locally and accepting connections on that socket?
psql: error: connection to server on socket "/var/run/postgresql/.s.PGSQL.5432" failed: No such file or directory
        Is the server running locally and accepting connections on that socket?
psql: error: connection to server on socket "/var/run/postgresql/.s.PGSQL.5432" failed: No such file or directory
        Is the server running locally and accepting connections on that socket?
azureuser@vaanee-test-new:~/vaanee$ 
