#!/bin/sh -e

DIRNAME=`dirname $0`
cd $DIRNAME
USAGE="$0 [ --update ]"
if [ `id -u` != 0 ]; then
    echo 'You must be root to run this script'
    exit 1
fi

if [ $# -eq 1 ]; then
    if [ "$1" = "--update" ] ; then
        time=`ls -l --time-style="+%x %X" amazon_cloudwatch_agent.te | awk '{ printf "%s %s", $6, $7 }'`
        rules=`ausearch --start $time -m avc --raw -se amazon_cloudwatch_agent`
        if [ x"$rules" != "x" ] ; then
            echo "Found avc's to update policy with"
            echo -e "$rules" | audit2allow -R
            echo "Do you want these changes added to policy [y/n]?"
            read ANS
            if [ "$ANS" = "y" -o "$ANS" = "Y" ] ; then
                echo "Updating policy"
                echo -e "$rules" | audit2allow -R >> amazon_cloudwatch_agent.te
                # Fall through and rebuild policy
            else
                exit 0
            fi
        else
            echo "No new avcs found"
            exit 0
        fi
    else
        echo -e $USAGE
        exit 1
    fi
elif [ $# -ge 2 ] ; then
    echo -e $USAGE
    exit 1
fi

echo "Building and Loading Policy"
set -x
make -f /usr/share/selinux/devel/Makefile amazon_cloudwatch_agent.pp || exit
/usr/sbin/semodule -i amazon_cloudwatch_agent.pp

# Fixing the file context on /opt/aws/amazon-cloudwatch-agent
# Fixing the file context on CloudWatch agent files
/sbin/restorecon -R -v /opt/aws/amazon-cloudwatch-agent || true
/sbin/restorecon -v /usr/lib/systemd/system/amazon-cloudwatch-agent.service || true

echo "Policy loaded. You may need to restart the CloudWatch agent: systemctl restart amazon-cloudwatch-agent"