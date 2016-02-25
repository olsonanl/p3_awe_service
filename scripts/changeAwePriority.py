#!env python

import requests
import os
import sys

auth_headers = {'Authorization': 'OAuth ' + os.environ['AWE_TOKEN']}
awe_api = 'https://kbase.us/services/awe-api'

awe_query_jobs = '/job?query&limit=2000&info.user='
#awe_list_jobs = '/job?query&limit=1000'

# is there a better way to do this?
verbosity = False

def changeAwePriority(newPriority,username):
    if (verbosity == True):
        print >> sys.stderr, "changing priority for user " + username + " to " + str(newPriority)

    req = requests.get(awe_api+awe_query_jobs+username, headers=auth_headers)
    awe_jobs = req.json()
#    print >> sys.stderr, awe_jobs

    for job in awe_jobs['data']:
        #print >> sys.stderr, job
        if (job['state'] != 'queued'):
            continue
# shouldn't get here yet, use later for debugging
            if (verbosity == True):
                print >> sys.stderr, job['id'] + ' not queued'

        priorityUrl=awe_api+'/job/'+job['id']+'?priority='+str(newPriority)

        if (verbosity == True):
            print >> sys.stderr, job['id'] + ' currently in state ' + job['state']
            print >> sys.stderr, job['id'] + ' current priority ' + str(job['info']['priority'])
            print >> sys.stderr, priorityUrl

        priorityReq = requests.put(priorityUrl, headers=auth_headers)
        if (verbosity == True):
            print >> sys.stderr, priorityReq.json()

if __name__ == "__main__":
    import argparse

# to do:
# make awe base URL configurable (with reasonable default)
# make stderr messages more configurable (i.e., make verbosity an int instead of boolean)
# make an option to operate only on queued jobs (default) or all jobs (for debugging)
    parser = argparse.ArgumentParser(description='Change priority of all of users\' AWE jobs.')
    parser.add_argument('-p', '--priority', nargs=1, type=int, help='new priority of jobs', required=True)
#    parser.add_argument('--debug',action='store_true',help='debugging')
    parser.add_argument('--verbose',action='store_true',help='be verbose')
    parser.add_argument('usernames', nargs='+', help='list of users to change')

    args = parser.parse_args()
    verbosity = args.verbose

    for username in args.usernames:
        changeAwePriority(args.priority[0],username)
