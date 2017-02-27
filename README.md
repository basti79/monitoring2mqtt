# monitoring2mqtt
Executing Nagios like monitoring checks and pushing resultus into MQTT

Copy monitoring2mqtt.conf.example to monitoring2mqtt.conf and edit. The rules are:
* Host define with hostname in square braces.
* Checks defined before the first host are the default commands.
* Check names must not contain spaces, everything after the first space is the command.
* Each host may...
  * use default checks, by giving the check name on a single line.
  * overwrite the default checks, by using the same name but defining a new command.
  * have its own checks, by defining a new check name and command.
* The pattern %HOST% in commands is replaced with the hostname.

The checks are currently executed one after another and the results are published into the MQTT broker running on localhost.

