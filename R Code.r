---
title: "Untitled"
output:
  html_document: default
  pdf_document: default
date: "2024-05-15"
---

```{r setup, include=FALSE}
knitr::opts_chunk$set(echo = TRUE)
```

## R Markdown
```{r}
# Install required packages
required_packages <- c("readxl", "caret", "gbm", "randomForest", "xgboost", "forecast", "keras", "e1071", "cluster", "GA", "ggplot2", "kernlab","maps")

for (pkg in required_packages) {
  if (!require(pkg, character.only = TRUE)) {
    install.packages(pkg, dependencies = TRUE)
  }
}

# Load necessary libraries
library(readxl)
library(caret)
library(gbm)
library(randomForest)
library(xgboost)
library(forecast)
library(keras)
library(e1071)
library(cluster)
library(GA)
library(ggplot2)
library(kernlab)

# Define the file path
file_path <- "C:/Users/kolpe/OneDrive/Desktop/UB/Syllabus/EAS508/SDM Group Project/Sales Data for Economic Data Analysis/Datasetre.xlsx"

# Read the data
data <- read_excel(file_path)

# Data preprocessing
data$Date <- as.Date(data$Date, format="%m/%d/%Y")
data$Year <- as.factor(data$Year)
data$Month <- as.factor(data$Month)
data$Customer_Gender <- as.factor(data$Customer_Gender)
data$Country <- as.factor(data$Country)
data$State <- as.factor(data$State)
data$Product_Category <- as.factor(data$Product_Category)
data$Sub_Category <- as.factor(data$Sub_Category)

# Remove rows with missing values
data <- na.omit(data)

# Split data into training and testing sets
set.seed(123)
trainIndex <- createDataPartition(data$Revenue, p = .8, list = FALSE, times = 1)
trainData <- data[trainIndex,]
testData <- data[-trainIndex,]

# Set up training control
train_control <- trainControl(method = "cv", number = 10)


# Sales Forecasting using Time Series Analysis and Gradient Boosting
ts_data <- ts(trainData$Revenue, frequency = 12) # Assuming monthly data
fit_ts <- auto.arima(ts_data)
forecast_ts <- forecast(fit_ts, h = nrow(testData))
ts_predictions <- as.numeric(forecast_ts$mean)



# Train GBM model without printing warnings
gbm_model <- suppressWarnings(
    train(Revenue ~ ., data = trainData, method = "gbm", trControl = train_control, verbose = FALSE)
)
gbm_predictions <- predict(gbm_model, testData)

combined_predictions <- (ts_predictions + gbm_predictions) / 2
rmse_combined <- RMSE(combined_predictions, testData$Revenue)
cat("RMSE for Combined Model: ", rmse_combined, "\n")

# Improved Plotting of sales forecasting results
color_palette <- c("Actual Revenue" = "#2C3E50", "Predicted Revenue" = "#E74C3C")
ggplot() +
  geom_line(aes(x = 1:nrow(testData), y = testData$Revenue, color = "Actual Revenue"), size = 1.2) +
  geom_line(aes(x = 1:nrow(testData), y = combined_predictions, color = "Predicted Revenue"), size = 1.2) +
  labs(
    title = "Sales Forecasting: Actual vs Predicted Revenue",
    x = "Time (Observation Points)",
    y = "Revenue",
    color = "Legend"
  ) +
  scale_color_manual(values = color_palette) +
  theme_minimal() +
  theme(
    text = element_text(size = 16),
    title = element_text(face = "bold", size = 20),
    legend.position = "bottom",
    legend.title = element_text(size = 14),
    legend.text = element_text(size = 12),
    axis.title = element_text(size = 18),
    axis.text = element_text(size = 14),
    plot.margin = unit(c(1, 1, 1, 1), "cm")
  ) +
  scale_x_continuous(breaks = seq(1, nrow(testData), by = 1))  # Adjust 'by' based on data size



# Customer Segmentation using SVM and Clustering
scaled_data <- scale(trainData[, c("Customer_Age", "Quantity", "Revenue")])
scaled_testData <- scale(testData[, c("Customer_Age", "Quantity", "Revenue")])

assign_clusters <- function(new_data, centers) {
  distances <- as.matrix(dist(rbind(centers, new_data)))
  distances <- distances[(nrow(centers)+1):nrow(distances), 1:nrow(centers)]
  apply(distances, 1, which.min)
}

kmeans_model <- kmeans(scaled_data, centers = 3)
trainData$Cluster <- as.factor(kmeans_model$cluster)
testData$Cluster <- assign_clusters(scaled_testData, kmeans_model$centers)
testData$Cluster <- as.factor(testData$Cluster)

svm_model <- train(Cluster ~ Customer_Age + Quantity + Revenue, data = trainData, method = "svmLinear", trControl = train_control)
svm_predictions <- predict(svm_model, testData)

table(testData$Cluster, svm_predictions)

color_palette <- c("1" = "#3498DB", "2" = "#E74C3C", "3" = "#2ECC71")

ggplot(trainData, aes(x = Customer_Age, y = Revenue, color = Cluster)) +
  geom_point(aes(shape = Cluster), size = 4, alpha = 0.6) +  # Adjust point size and transparency
  scale_color_manual(values = color_palette) +
  labs(
    title = "Customer Segmentation by Age and Revenue",
    x = "Customer Age",
    y = "Revenue",
    color = "Cluster"
  ) +
  theme_minimal() +
  theme(
    plot.title = element_text(face = "bold", size = 16, hjust = 0.5),
    axis.title = element_text(size = 14),
    axis.text = element_text(size = 12),
    legend.title = element_text(size = 12),
    legend.text = element_text(size = 11),
    legend.position = "right"
  ) +
  scale_shape_manual(values = c(16, 17, 18))



# Adaptive Pricing using Genetic Algorithms
fitness_function <- function(prices) {
  simulated_revenue <- sum(prices * testData$Quantity)
  return(simulated_revenue)
}

ga_model <- ga(type = "real-valued", fitness = fitness_function, lower = rep(1, nrow(testData)), upper = rep(100, nrow(testData)), popSize = 50, maxiter = 100, run = 50)
optimal_prices <- ga_model@solution
cat("Optimal Prices: ", optimal_prices, "\n")


simulated_revenue <- sum(optimal_prices * testData$Quantity)
cat("Simulated Revenue: ", simulated_revenue, "\n")


optimal_prices_df <- data.frame(Time = 1:nrow(testData), OptimalPrices = optimal_prices)
ggplot(optimal_prices_df, aes(x = Time, y = optimal_prices)) +
  geom_line(color = "#3498DB", size = 1.2) +  # Thicker line for better visibility
  geom_point(color = "#E74C3C", size = 3, shape = 21, fill = "#3498DB") +  # Points with a distinct fill and border color
  labs(
    title = "Optimal Prices Over Time",
    x = "Time (Observation Points)",
    y = "Optimal Prices ($)",
    caption = "Data reflects dynamically calculated optimal prices for maximizing revenue."
  ) +
  theme_minimal() +
  theme(
    plot.title = element_text(face = "bold", size = 16, hjust = 0.5),
    axis.title = element_text(size = 14),
    axis.text = element_text(size = 12),
    legend.position = "none",  # No legend needed
    plot.caption = element_text(size = 10, hjust = 0, vjust = 1.5),
    panel.grid.minor = element_blank()  # Remove minor gridlines for a cleaner look
  ) +
  scale_x_continuous(breaks = seq(1, nrow(testData), by = 5))




# Decompose time series to trend, seasonal, and random components
ts_decompose <- decompose(ts(trainData$Revenue, frequency=12))

# Plotting the decomposed components
plot(ts_decompose, xlab = "Time", ylab = "Revenue")



# Plotting clusters with centroids
ggplot(trainData, aes(x = Customer_Age, y = Revenue, color = Cluster)) +
  geom_point(aes(shape = Cluster), alpha = 0.6) +
  geom_point(data = data.frame(kmeans_model$centers), aes(x = Customer_Age, y = Revenue), color = "black", size = 5, shape = 8) +
  scale_color_manual(values = color_palette) +
  labs(title = "Cluster Distribution with Centroids",
       x = "Customer Age",
       y = "Revenue") +
  theme_minimal()




# Calculate revenues for optimal prices
optimal_revenues <- optimal_prices * testData$Quantity

# Data for plotting
pricing_data <- data.frame(Time = 1:nrow(testData), Prices = optimal_prices, Revenue = optimal_revenues)

# Plotting prices and revenue
ggplot(pricing_data) +
  geom_line(aes(x = Time, y = optimal_prices, color = "Optimal Prices"), size = 1.2) +
  geom_line(aes(x = Time, y = optimal_prices, color = "Simulated Revenue"), size = 1.2) +
  scale_color_manual(values = c("Optimal Prices" = "#3498DB", "Simulated Revenue" = "#E74C3C")) +
  labs(title = "Dynamic Pricing Strategy: Price vs. Revenue",
       x = "Time (Observation Points)",
       y = "Value") +
  theme_minimal() +
  theme(legend.position = "bottom")




# Calculate correlation matrix
cor_matrix <- cor(trainData[, c("Customer_Age", "Quantity", "Revenue")])

# Plotting heatmap
ggplot(data = as.data.frame(as.table(cor_matrix)), aes(Var1, Var2, fill = Freq)) +
  geom_tile(color = "white") +
  scale_fill_gradient2(low = "blue", high = "red", mid = "white", midpoint = 0, limit = c(-1, 1), space = "Lab", name="Correlation") +
  theme_minimal() +
  labs(x = "", y = "", title = "Feature Correlation Heatmap") +
  coord_fixed()





ggplot(data, aes(x = Product_Category, y = Revenue, fill = Product_Category)) +
  geom_boxplot() +
  labs(title = "Revenue Distribution by Product Category", x = "Product Category", y = "Revenue") +
  theme_minimal() +
  theme(axis.text.x = element_text(angle = 45, hjust = 1))


ggplot(data, aes(x = Customer_Gender, y = Revenue, fill = Customer_Gender)) +
  geom_boxplot() +
  labs(title = "Revenue by Customer Gender", x = "Gender", y = "Revenue") +
  theme_minimal()





# Install and load required packages
if (!require("ggplot2")) install.packages("ggplot2")
if (!require("rnaturalearth")) install.packages("rnaturalearth")
if (!require("rnaturalearthdata")) install.packages("rnaturalearthdata")

library(ggplot2)
library(rnaturalearth)
library(rnaturalearthdata)

# Ensure that 'Country' is treated as a factor
data$Country <- as.factor(data$Country)

# Aggregate revenue by country
countries_revenue <- aggregate(Revenue ~ Country, data, sum)

# Retrieve world map data
world <- ne_countries(scale = "medium", returnclass = "sf")

# Merge data with map data
# The names in the merge function must match the actual column names for both datasets
map_data <- merge(world, countries_revenue, by.x = "name", by.y = "Country", all.x = TRUE)

# Plotting the choropleth map
ggplot(map_data, aes(geometry = geometry, fill = Revenue)) +
  geom_sf(color = "white") +
  scale_fill_viridis_c(option = "plasma", na.value = "grey50", label = scales::comma) +
  labs(fill = "Revenue", title = "Revenue Contribution by Country") +
  theme_minimal()



forecast_data <- data.frame(Time = 1:nrow(testData), Actual = testData$Revenue, Forecast = combined_predictions)

ggplot(forecast_data, aes(x = Time)) +
  geom_line(aes(y = Actual, color = "Actual Revenue")) +
  geom_line(aes(y = Forecast, color = "Forecasted Revenue"), linetype = "dashed") +
  scale_color_manual(values = c("Actual Revenue" = "#3498DB", "Forecasted Revenue" = "#E74C3C")) +
  labs(title = "Actual vs Forecasted Revenue", x = "Time", y = "Revenue") +
  theme_minimal() +
  theme(legend.position = "bottom")



# Calculate correlation matrix
cor_matrix <- cor(trainData[, c("Customer_Age", "Quantity", "Revenue")])

# Use melt from the reshape2 package
cor_data <- reshape2::melt(cor_matrix)

# Plotting heatmap
ggplot(cor_data, aes(Var1, Var2, fill = value)) +
  geom_tile(color = "white") +
  scale_fill_gradient2(midpoint = 0, limit = c(-1, 1), space = "Lab", name = "Correlation") +
  labs(title = "Feature Correlation Matrix") +
  theme_minimal() +
  theme(axis.text.x = element_text(angle = 45, vjust = 1, hjust = 1))





# Summary of results
# Execute resamples and summary without showing any warnings
results <- suppressWarnings(resamples(list(GBM = gbm_model, SVM = svm_model)))
summary_results <- suppressWarnings(summary(results))

# Print the summary results
print(summary_results)
# Save the current warning level
old_warn <- options("warn")

# Set the warning level to ignore all warnings (-1)
options(warn = -1)

# Execute code that might generate warnings
results <- resamples(list(GBM = gbm_model, SVM = svm_model))
summary_results <- summary(results)

# Print the summary results
print(summary_results)

# Restore previous warning level
options(old_warn)


```


```{r}

```

