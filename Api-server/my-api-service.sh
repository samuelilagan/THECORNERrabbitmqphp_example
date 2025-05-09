#!/bin/bash

cd /home/samilagan/git/rabbitmqphp_example/Api-server

#ran "which node" to see where node was located: /usr/bin/node
#make sure this file is executable!
#btw you commented out the cron job in crontab -e!!!!!!!
/usr/bin/node /home/samilagan/git/rabbitmqphp_example/Api-server/fetchReviews.js