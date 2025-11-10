# Variante recommandée via Microsoft Build of OpenJDK
FROM mcr.microsoft.com/openjdk/jdk:21-ubuntu
EXPOSE 8089
ADD target/timesheet-devops-1.0.jar timesheet-devops-1.0.jar
ENTRYPOINT ["java","-jar","/timesheet-devops-1.0.jar"]
