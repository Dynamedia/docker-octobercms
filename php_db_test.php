#!/usr/local/bin/php
<?php

$driver = $argv[1];
$host = $argv[2];
$port = $argv[3];
$dbUser = $argv[4];
$dbPass = $argv[5];
$dbName = $argv[6];

if (!$driver || !$host || !$port || !$dbUser || !$dbPass || !$dbName) {
    echo "You have not specified the required args (driver, host, port, dbUser, dbPass, dbName). Check your environemt\n";
    die(1);
}

// Only do checking for mysql and pgsql. sqlite db WILL be present if entrypoint.sh is not broken.
if ($driver == 'mysql' || $driver == 'pgsql') {
    $retries = 0;
    while ($retries < 10) {
        try {
            if (testDbConnection($driver, $host, $port, $dbUser, $dbPass, $dbName)) {
                echo "Successfully connected to the database\n";
                return 0;
            } else {
                echo "Unable to connect to the database. Waiting 5 seconds...\n";
                $retries++;
                sleep(5);
            }
        } catch (\Exception $ex) {
            $msg = $ex->getMessage();
            echo "Fatal. Unable to connect to the database ($msg)\n";
            die(1);
        }
    }
} else {
    echo "This database does not require connection checks\n";
    return 0;
}


echo "Fatal. Unable to connect to the database\n";
die(1);

function testDbConnection($driver, $host, $port, $dbUser, $dbPass, $dbName)
{
    try {
        $dbh = new pdo("$driver:host=$host:$port;dbname=$dbName",
            "$dbUser",
            "$dbPass",
            array(PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION));
        return true;
    } catch (PDOException $ex) {
        $err = $ex->getCode();
        $msg = $ex->getMessage();
        if ($err == 2002) {
            return false;
        } else {
            throw new \Exception("Fatal. Could not connect to the database ($msg)", 1);
        }
    }
}
