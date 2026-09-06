import numpy as np
import pandas as pd
import tensorflow as tf
from sklearn.model_selection import train_test_split

print("🚀 Step 1: Generating Smart Dummy Data (Vectorized)...")

np.random.seed(42)
num_samples = 2000

# 1. Generate random inputs
task_types = np.random.choice([0, 1, 2], size=num_samples) # 0: Workout, 1: Focus, 2: Chores
times_of_day = np.round(np.random.uniform(6.0, 22.0, size=num_samples), 1)
temperatures = np.round(np.random.uniform(10.0, 35.0, size=num_samples), 1)
is_raining = np.random.choice([0, 1], p=[0.7, 0.3], size=num_samples)

# 2. Vectorized logic for 'target_success' (Much faster than a for-loop)
chance = np.full(num_samples, 0.5) # Base 50% chance

# Pattern A: Workouts (0)
is_workout = (task_types == 0)
chance[is_workout & (is_raining == 1)] -= 0.4
chance[is_workout & (temperatures > 30.0)] -= 0.2
chance[is_workout & (times_of_day < 9.0)] += 0.3

# Pattern B: Deep Work (1)
is_focus = (task_types == 1)
chance[is_focus & (is_raining == 1)] += 0.2
chance[is_focus & (times_of_day > 19.0)] -= 0.3

# Pattern C: Chores (2)
is_chore = (task_types == 2)
chance[is_chore & (times_of_day >= 12.0) & (times_of_day <= 17.0)] += 0.2

# Add noise, clip between 0 and 1, and convert to binary success (1 or 0)
chance += np.random.uniform(-0.1, 0.1, size=num_samples)
chance = np.clip(chance, 0, 1)
success = (chance >= 0.5).astype(int)

# 3. Save to CSV
df = pd.DataFrame({
    'task_type': task_types,
    'time_of_day': times_of_day,
    'temperature': temperatures,
    'is_raining': is_raining,
    'target_success': success
})
df.to_csv('routine_data.csv', index=False)
print("✅ Created routine_data.csv!")

print("\n🧠 Step 2: Training the Neural Network...")

# 4. Prepare data
X = df[['task_type', 'time_of_day', 'temperature', 'is_raining']].values
y = df['target_success'].values

X_train, X_test, y_train, y_test = train_test_split(X, y, test_size=0.2, random_state=42)

# 5. Embed Normalization inside the model! 
# (This ensures the Flutter app can just send raw numbers without doing math)
normalizer = tf.keras.layers.Normalization(axis=-1)
normalizer.adapt(X_train) # Learns the mean and variance of your data

# 6. Build a robust, lightweight model
model = tf.keras.Sequential([
    normalizer, # Scales inputs automatically!
    tf.keras.layers.Dense(32, activation='relu'),
    tf.keras.layers.Dropout(0.2), # Prevents overfitting (memorizing the data)
    tf.keras.layers.Dense(16, activation='relu'),
    tf.keras.layers.Dense(1, activation='sigmoid') # Outputs probability (0.0 to 1.0)
])

model.compile(optimizer='adam', loss='binary_crossentropy', metrics=['accuracy'])

# 7. Use Early Stopping to stop training when the model stops improving
early_stop = tf.keras.callbacks.EarlyStopping(
    monitor='val_loss', 
    patience=5, 
    restore_best_weights=True
)

# 8. Train the model
print("Training Model...")
history = model.fit(
    X_train, y_train, 
    epochs=50, # Increased epochs because early stopping will catch it if it finishes early
    batch_size=32, 
    validation_data=(X_test, y_test),
    callbacks=[early_stop],
    verbose=1
)

# Evaluate final accuracy
loss, accuracy = model.evaluate(X_test, y_test, verbose=0)
print(f"\n🎯 Final Model Test Accuracy: {accuracy * 100:.2f}%")

print("\n📦 Step 3: Converting & Optimizing for Mobile...")

# 9. Convert to TFLite with Mobile Optimizations
converter = tf.lite.TFLiteConverter.from_keras_model(model)
converter.optimizations = [tf.lite.Optimize.DEFAULT] # Quantizes the model (makes it tiny!)
tflite_model = converter.convert()

with open('routine_predictor.tflite', 'wb') as f:
    f.write(tflite_model)

print("🎉 Success! Optimized 'routine_predictor.tflite' is ready for Flutter.")