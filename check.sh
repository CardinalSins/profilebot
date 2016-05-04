#!/bin/bash
#
# Bot Checker
# Based on BotCheck Copyright (C) 1999, 2000, 2001, 2002, 2003 Jeff Fisher <guppy@eggheads.org>
#

# change this to the nickname of your bot (capitalization COUNTS)
BOT="Jeeves"

# change this to the directory you run your bot from:
botdir=`pwd`
logfile=$botdir/debug.log

# change this to the name of your bot's script in that directory:
botscript="perl poco-bot.pl"

# change this to the name of your bot's pidfile (capitalization COUNTS)
PID=".bot.pid"

########## you probably don't need to change anything below here ##########

cd $botdir

logger() {
    message=$1
    stamp=`date +'%Y-%m-%d %R:%S'`
    echo "$stamp: $message" >> $logfile
}

# is there a pid file?
if [ -r $PID ] ; then
    # there is a pid file -- is it current?
    botpid=`cat $PID`
    if `kill -CHLD $botpid >/dev/null 2>&1` ; then
        logger "Bot running, exiting with extreme prejudice"
        exit 0
    fi
    logger "Stale $PID file, erasing..."
    rm -f $PID
fi

if [ -f .dead.$BOT ] ; then
    logger ".dead.$BOT exists, not starting..."
    exit 0
fi
$botscript

exit 0
