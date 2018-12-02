#!/usr/bin/env bash
set -e
set -o pipefail

DATABASE=
HOST=
PORT=5432
USER="postgres"
PASSWORD=
TESTS="/t/*.sql"

function usage() { echo "Usage: $0 -h host -d database -p port -u username -w password -t tests" 1>&2; exit 1; }

while getopts d:h:p:u:w:b:n:t: OPTION
do
  case $OPTION in
    d)
      DATABASE=$OPTARG
      ;;
    h)
      HOST=$OPTARG
      ;;
    p)
      PORT=$OPTARG
      ;;
    u)
      USER=$OPTARG
      ;;
    w)
      PASSWORD=$OPTARG
      ;;
    t)
      TESTS=$OPTARG
      ;;
    *)
      usage
      ;;
  esac
done

if [[ -z $DATABASE ]] || [[ -z $HOST ]] || [[ -z $PORT ]] || [[ -z $USER ]] || [[ -z $TESTS ]]
then
  usage
  exit 1
fi

echo "Waiting for postgres to be ready ($HOST:$PORT)"
while ! timeout 60 bash -c "cat < /dev/null > /dev/tcp/$HOST/$PORT" >/dev/null 2>&1; do sleep 1; done

echo "Install pgtap into db '$DATABASE'"
function psqlbatch() {
    # Worth reading: https://petereisentraut.blogspot.com/2010/03/running-sql-scripts-with-psql.html
    #  --set ON_ERROR_STOP=1 --single-transaction
    # since pgtap prints lots of errors on installation, we set min-messages to fatal
    # https://www.postgresql.org/docs/current/runtime-config-logging.html#GUC-CLIENT-MIN-MESSAGES
    PGOPTIONS='--client-min-messages=fatal' psql --no-psqlrc --quiet --pset pager=off "$@"
}
PGPASSWORD=$PASSWORD psqlbatch -h $HOST -p $PORT -d $DATABASE -U $USER -f /usr/share/postgresql/9.6/extension/pgtap--0.99.0.sql 2>&1
rc=$?

if [[ $rc != 0 ]] ; then
  echo "pgTap was not installed properly. Unable to run tests!"
  exit $rc
fi

echo "Running tests: $TESTS"
PGPASSWORD=$PASSWORD pg_prove -h $HOST -p $PORT -d $DATABASE -U $USER $TESTS
rc=$?

# TODO: uninstall pgtap

exit $rc
