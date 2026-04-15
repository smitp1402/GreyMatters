"""Quick test: can BrainFlow receive data from the Crown?"""

import time
from brainflow.board_shim import BoardIds, BoardShim, BrainFlowInputParams

board_id = BoardIds.CROWN_BOARD.value
params = BrainFlowInputParams()
board = BoardShim(board_id, params)

BoardShim.enable_dev_board_logger()

print("Preparing session...")
board.prepare_session()

print("Starting stream...")
board.start_stream()

print("Collecting data for 10 seconds...")
time.sleep(10)

data = board.get_board_data()
print(f"Data shape: {data.shape}")
print(f"Samples collected: {data.shape[1]}")

if data.shape[1] > 0:
    eeg_channels = BoardShim.get_eeg_channels(board_id)
    eeg = data[eeg_channels]
    print(f"EEG channels shape: {eeg.shape}")
    print(f"First 5 samples of F5: {eeg[2, :5]}")
    print(f"First 5 samples of F6: {eeg[5, :5]}")
else:
    print("NO DATA RECEIVED")

board.stop_stream()
board.release_session()
