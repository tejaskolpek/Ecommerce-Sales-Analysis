library(readr)
library(dplyr)
library(ggplot2)
library(caret)

# Load and prepare data
data <- read_csv("C:/Users/kolpe/OneDrive/Desktop/UB/Syllabus/EAS508/SDM Group Project/Sales Data for Economic Data Analysis/salesforcourse-4fe2kehu.csv", show_col_types = FALSE)  # Replace with actual file path
str(data)
head(data)

data <- na.omit(data)
data$Date <- as.Date(data$Date, format="%m/%d/%Y")w
data$Month <- as.factor(data$Month)

# Ensure factor variables have more than one level
if (length(unique(data$Month)) < 2) {
  stop("Error: Factor 'Month' does not have enough levels. Please adjust your data or remove this variable.")
}

# Split data
set.seed(123)
training_samples <- data$Date < as.Date("2015-01-01")  # Adjust this date as needed
train_data <- data[training_samples, ]
test_data <- data[!training_samples, ]

# Check factor levels in training data
factor_vars <- sapply(train_data, is.factor)  # Identify factor columns
for (var in names(factor_vars[factor_vars])) {
  if (length(unique(train_data[[var]])) < 2) {
    cat("Variable", var, "has only one level in the training data and will be removed.\n")
    train_data[[var]] <- NULL  # Remove the variable from train_data
    test_data[[var]] <- NULL  # Remove the variable from test_data
  }
}

# Re-check the structure to confirm
str(train_data)

# Build and train a model, ensure no problematic factors are included
model <- lm(Revenue ~ ., data = train_data)
summary(model)

# Alternatively, reconsider the data splitting or preprocessing to ensure more balanced factor levels

# Build and train a model

# Evaluate the model
predictions <- predict(model, test_data)
actuals <- test_data$Revenue
RMSE <- sqrt(mean((predictions - actuals)^2))
print(paste("RMSE:", RMSE))

# Plot predictions vs actuals
ggplot(data.frame(Actual = actuals, Prediction = predictions), aes(x = Actual, y = Prediction)) +
  geom_point() +
  geom_abline(slope = 1, intercept = 0, col = "red") +
  labs(title = "Actual vs. Predicted Revenue")