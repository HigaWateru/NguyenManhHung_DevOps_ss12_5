#!/bin/sh

# Standard POSIX wrapper script for Gradle
# Executed in GitHub Actions ubuntu-latest runner

set -e

# Resolve APP_HOME
APP_HOME=$(cd "$(dirname "$0")" && pwd)

# Determine the Java command to use to start the JVM.
if [ -n "$JAVA_HOME" ] ; then
    JAVACMD="$JAVA_HOME/bin/java"
else
    JAVACMD="java"
fi

# Download gradle wrapper jar if missing or run gradle directly
CLASSPATH="$APP_HOME/gradle/wrapper/gradle-wrapper.jar"

if [ ! -f "$CLASSPATH" ]; then
    # Fallback to system gradle if available or download wrapper jar
    if command -v gradle >/dev/null 2>&1; then
        exec gradle "$@"
    else
        mkdir -p "$APP_HOME/gradle/wrapper"
        echo "Downloading gradle-wrapper.jar..."
        curl -sLo "$CLASSPATH" https://raw.githubusercontent.com/gradle/gradle/v8.5.0/gradle/wrapper/gradle-wrapper.jar || true
    fi
fi

if [ -f "$CLASSPATH" ]; then
    exec "$JAVACMD" -jar "$CLASSPATH" "$@"
else
    gradle "$@"
fi
