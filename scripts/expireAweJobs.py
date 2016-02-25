#!env python

# To do:
# add if __main__
# do most work in a def
# actually send the DELETE from script instead of needing to pass through an xargs
# add verbose and debug switches

import requests
import datetime
import os
import dateutil.parser
import pytz
import sys

expire_hours = 30 * 24
auth_headers = {'Authorization': 'OAuth ' + os.environ['AWE_TOKEN']}
awe_api = 'https://kbase.us/services/awe-api'
awe_list_jobs = '/job?query&state=suspend&limit=2000'
#awe_list_jobs = '/job?query&limit=1000'

req = requests.get(awe_api+awe_list_jobs, headers=auth_headers)
awe_jobs = req.json()

#print awe_jobs

now = datetime.datetime.now(pytz.utc)
expire_interval = datetime.timedelta(hours=expire_hours)
#print expire_interval

for job in awe_jobs['data']:
#    print job['id']
#    print job['updatetime']
    job_time = dateutil.parser.parse(job['updatetime'])
#    print job_time
#    job_time = dateutil.parser.parse(job['info']['submittime'])
#    print job_time
#    print now
    print >> sys.stderr, job['id'] + ' currently in state ' + job['state']
    if ( ( now - job_time ) > expire_interval ):
        print >> sys.stderr, job['id'] + ' currently in state ' + job['state']
        print job['id']
