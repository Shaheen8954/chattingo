# ------------------------------------------------------------
# ==================== Dependencies stage ===========================
# ------------------------------------------------------------
  FROM maven:3.8.5-openjdk-17-slim AS deps
  WORKDIR /backend
  # cache dependencies
  COPY pom.xml ./
  RUN mvn -q -DskipTests dependency:go-offline
  
  # ------------------------------------------------------------
  # ==================== Build stage =========================
  # ------------------------------------------------------------
  
  FROM maven:3.8.5-openjdk-17-slim AS build
  WORKDIR /backend
  COPY --from=deps /root/.m2 /root/.m2
  COPY . .
  RUN mvn -q -DskipTests package
  
  # ------------------------------------------------------------
  # ==================== Runtime stage ==========================
  # ------------------------------------------------------------
  FROM gcr.io/distroless/java17-debian12 AS runtime
  WORKDIR /app
  COPY --from=build /backend/target/*jar /app/app.jar
  USER nonroot
  EXPOSE 8080
  ENTRYPOINT ["java","-jar","/app/app.jar"]