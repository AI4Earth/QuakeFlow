import streamlit as st
from collections import defaultdict
from kafka import KafkaConsumer
from json import loads
import time
import numpy as np
from datetime import datetime
import matplotlib.pyplot as plt

consumer = KafkaConsumer(
    'testtopic',
    bootstrap_servers=['localhost:9092'],
    auto_offset_reset='earliest',
    enable_auto_commit=True,
    group_id='my-group',
    key_deserializer=lambda x: loads(x.decode('utf-8')),
    value_deserializer=lambda x: loads(x.decode('utf-8'))
)

normalize = lambda x: (x - np.mean(x) + np.finfo(x.dtype).eps)/(np.std(x)+np.finfo(x.dtype).eps)

wave_dict = defaultdict(list)
window_size = 50
dt = 0.01
prev_time = time.time()

num_plot = 0
for i, message in enumerate(consumer):
    
    key = message.key
    timestamp = message.value[0]
    vec = message.value[1]
    t = datetime.fromisoformat(timestamp).timestamp() + np.arange(len(vec))*dt

    wave_dict[key].append((t, vec))
    wave_dict[key] = wave_dict[key][-window_size:]

    if time.time() - prev_time > 1.1:
        prev_time = time.time()

        keys = sorted(wave_dict.keys())
        plot_data = {}
        for i, k in enumerate(keys):
            plot_data[k] = []
            for j in range(window_size - len(wave_dict[k])):
                plot_data[k].extend([[0] * 3] * 100)
            for v in wave_dict[k]:
                plot_data[k].extend(v[1])
            plot_data[k] = normalize(np.array(plot_data[k])[::5,-1])/8 + i

        if num_plot == 0:
            handle = st.line_chart(plot_data)
        else:
            handle.line_chart(plot_data)
        num_plot += 1
