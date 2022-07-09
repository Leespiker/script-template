# using multistage docker build
# ref: https://docs.docker.com/develop/develop-images/multistage-build/

# temp container to cache gradle
FROM gradle:7.4.2-jdk17-alpine AS cache
# Environment vars
ENV APP_HOME /app
WORKDIR $APP_HOME
# Copy gradle settings and config to /app in the image
COPY build.gradle settings.gradle gradlew $APP_HOME
COPY gradle $APP_HOME/gradle
# Build gradle - caches dependencies
RUN ./gradlew --no-daemon build || return 0

# Clone the OsrsBot repo to build the jar
RUN git clone https://github.com/OSRSB/OsrsBot.git /OsrsBot/
# Gradle settings needs to be updated to be the same as OsrsBot
#RUN git clone https://github.com/OSRSB/DaxWalkerOSRSBot.git /DaxWalkerOSRSBot/

# Copy our scripts source and build the project
COPY src/ /src
RUN ./gradlew --no-daemon build

# actual container

# Set base image from Docker image repo
# https://adoptium.net/temurin
FROM eclipse-temurin:17-jre-centos7

ENV APP_HOME /app
# Name of the built OSRSBot jar file
ENV BOT_JAR_FILE OsrsBot.jar

# Installs XDisplay packages so we can actually view the container (and run the bot)
RUN yum install libXext.x86_64 libXrender.x86_64 libXtst.x86_64 -y

# Adds the bot jar to the container
COPY --from=cache $APP_HOME/$BOT_JAR_FILE $BOT_JAR_FILE
# Adds the scripts to the container
COPY --from=cache $APP_HOME/build/libs root/.config/OsrsBot/Scripts/Precompiled

# Exposes a port to connect via
EXPOSE 8080

# Runs the bot with the bot flag
ENTRYPOINT exec java -jar ${BOT_JAR_FILE} -bot-runelite -developer-mode

# Looped entry for debugging the image
#ENTRYPOINT ["tail", "-f", "/dev/null"]