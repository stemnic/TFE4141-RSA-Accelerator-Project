
# RSA Integration Kit
This document demonstrates encryption and decryption of a file using a dedicated RSA accelerator for the PYNQ platform. It is developed as a part of the term project given in the course TFE4141 Design of Digital Systems 1 at the Department of Electronic Systems at the Norwegian University of Science and Technology.


# Digital design flow

Before starting the work on designing a digital circuit, a reminder of the digital hardware design flow is in place. 

1) Capture the requirements

2) Create a high level functional model. This model must produce the correct result, but is written at a very high abstraction level.

3) Design exploration. Use models at different abstraction levels. Try out different algorithms. What asymptotic complexity do they have? Is the problem parallelizable in any way? Can you use multiple cores and/or pipeline the design to increase the throughput?

4) Propose a microarchitecture at the register transfer level. The block diagram should be detailed enough that it identifies registers, muxes, adders and similar units. 

5) Estimate the performance and the area of your design. Estimate the clock frequency as well as the throughput.

6) Write the RTL kode for your design.

7) Verify functional correctness of the design. Use e.g. constrained random self checking testbenches or formal verification. 

8) Verify the performance of the design. Create special test in order to check that the performance is as expected.

9) Prototype the design e.g. on an FPGA. Do system testing.


# Constants
The following constants must be set to the appropriate values before attempting any encrypt/decrypt operations.


```python
# ------------------------------------------------------------------------------
# Set the blocksize
# ------------------------------------------------------------------------------
C_BLOCKSIZE_IN_BITS         = 256
C_BLOCKSIZE_IN_32_BIT_WORDS = 8
C_BLOCKSIZE_IN_BYTES        = 32

# ------------------------------------------------------------------------------
# It is possible to choose between two different algorithms: 
#   XOR: This is the algorithm you can use for testing the system before you
#        have integrated the RSA hardware accelerator.
#        Computes: C=M xor n, M=C xor n
#
#   RSA: This is the algorithm you must enable when you have integrated the
#        RSA hardware accelerator.
#        Computes: C=M**e mod n, M=C**d mod n
# ------------------------------------------------------------------------------
C_ENCR_ALGORITHM_XOR = 0
C_ENCR_ALGORITHM_RSA = 1
C_ENCR_ALGORITHM = C_ENCR_ALGORITHM_XOR

# ------------------------------------------------------------------------------
# Import python libraries
# ------------------------------------------------------------------------------
import numpy as np
import time
```

# Utility functions

Messages will be read and written to files and sent in and out of the Pynq platform. In the following section a few utility functions for moving and converting data has been implemented.


```python
# ------------------------------------------------------------------------------
# Function for converting an array of messages to a numpy array of 32-bit words
# ------------------------------------------------------------------------------
def msg2word(msg_array):
  word_array_array = []
  # Produce one word array per message
  for msg in msg_array: 
    msg_in_bytes = msg.to_bytes(C_BLOCKSIZE_IN_BYTES,byteorder='little')
    word_array_array.append(np.frombuffer(msg_in_bytes, dtype=np.uint32))
  
  # Concatentate the small word arrays into one large
  word_array = np.concatenate(word_array_array)    
  
  # Return the array of words
  return word_array

# ------------------------------------------------------------------------------
# Function for converting an numpy array of 32-bit words into messages
# ------------------------------------------------------------------------------
def word2msg(word_array):
  msg_array = []

  # Check that the message array size is a multiplum of 8 32 bit words
  word_array_length = len(word_array)
  assert word_array_length%C_BLOCKSIZE_IN_32_BIT_WORDS == 0, "The file size must be aligned to the block size" 
  message_count = int(word_array_length/C_BLOCKSIZE_IN_32_BIT_WORDS)

  # Loop over all messages
  for i in range(message_count):
    
    # Concatinate 32-bit words to a 256-bit message
    M = 0
    for j in range(C_BLOCKSIZE_IN_32_BIT_WORDS):
      M += (int(word_array[i*C_BLOCKSIZE_IN_32_BIT_WORDS+j]) << (j*32))
    
    # Append the message
    msg_array.append(M)
    
  # Return the message array
  return msg_array

# ------------------------------------------------------------------------------
# Function for testing msg2word word2msg conversion
# ------------------------------------------------------------------------------
def test_msg2msg():

  ma_in = [0x0000000011111111222222223333333344444444555555556666666677777777,
           0x8888888899999999aaaaaaaabbbbbbbbccccccccddddddddeeeeeeeeffffffff]
  wa = msg2word(ma_in)
  ma_out = word2msg(wa)
  if(ma_in==ma_out):
    print("test_msg2msg: PASSED")
  else:
    print("test_msg2msg: FAILED")
    
# ------------------------------------------------------------------------------
# Run a test of the utility functions
# ------------------------------------------------------------------------------
test_msg2msg()    
```

    test_msg2msg: PASSED


# Message to encrypt/decrypt
The messages that will be encrypted/decrypted must all be downloaded from Blackboard and stored on the pynq platform. Copy the folder named "crypto" from Blackboard and paste it into the following location on the Pynq platform prior to running this jupyter notebook: 

/home/xilinx/pynq

The plaintex messages satisfy the following properties: 
* Property1: The size of the file must be a multiple of the block size, i.e. the filesize in bytes must be dividable by 32.
* Property2: C = M**e mod n, for 0 <= M < n. 

The second property has been satisfied through the following: 
* The files have been generated in such a way that they contain only ASCII characters with a byte value equal or lower than 127. The most significant bit in every byte is therefore 0, and thus it is also guaranteed that the MSB of any 256 bit blocks will be 0. 
* n is selected in such a way that the MSB of n is always 1.  


```python
from pathlib import Path

# Two sets of testcases exists. One set used when the RSA algorithm is
# selected and another set for the XOR algorithm.
if(C_ENCR_ALGORITHM == C_ENCR_ALGORITHM_RSA):
  inp_msgdir = """/home/xilinx/pynq/crypto/rsa/inp_messages/"""
  otp_hw_msgdir = """/home/xilinx/pynq/crypto/rsa/otp_hw_messages/"""
  otp_sw_msgdir = """/home/xilinx/pynq/crypto/rsa/otp_sw_messages/"""    
else:
  inp_msgdir = """/home/xilinx/pynq/crypto/xor/inp_messages/"""
  otp_hw_msgdir = """/home/xilinx/pynq/crypto/xor/otp_hw_messages/"""
  otp_sw_msgdir = """/home/xilinx/pynq/crypto/xor/otp_sw_messages/"""    

# Name of the files to encrypt and decrypt
inp_files = ["pt0_in.txt", "pt1_in.txt", "pt2_in.txt", "ct3_in.txt", "ct4_in.txt", "ct5_in.txt"]
otp_files = ["ct0_out.txt", "ct1_out.txt", "ct2_out.txt", "pt3_out.txt", "pt4_out.txt", "pt5_out.txt"]
crypt_dir = ["ENCR", "ENCR", "ENCR", "DECR", "DECR", "DECR"]

# Testcase count
num_testcases = len(inp_files)

# Function for retrieving filenames for the different testcases
def get_testcase(testcase_sel):
  inp_file    = Path(inp_msgdir    + inp_files[testcase_sel])
  otp_hw_file = Path(otp_hw_msgdir + otp_files[testcase_sel])
  otp_sw_file = Path(otp_sw_msgdir + otp_files[testcase_sel])
  direction   = crypt_dir[testcase_sel]
  return direction, inp_file, otp_hw_file, otp_sw_file

# Check whether or not the files exist
for i in range(num_testcases):
  direction, inp_file, otp_hw_file, otp_sw_file = get_testcase(i)
  if not(inp_file.is_file()):
    print("File %s is missing. Download the file from Blackboard!" % str(inp_file))

```

# Keys and key generation

Pseudocode for RSA key generation is available here: https://repl.it/@Snesemann/RSAKeyGenAndEncrypt

When encrypting and decrypting the files in this script, the following keys will be used:

<pre>
n: 99925173 ad656867 15385ea8 00cd2812 0288fc70 a9bc98dd 4c90d676 f8ff768d
e: 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00010001
d: 0cea1651 ef44be1f 1f1476b7 539bed10 d73e3aac 782bd999 9a1e5a79 0932bfe9
</pre>


```python
key_n = 0x99925173ad65686715385ea800cd28120288fc70a9bc98dd4c90d676f8ff768d
key_e = 0x0000000000000000000000000000000000000000000000000000000000010001
key_d = 0x0cea1651ef44be1f1f1476b7539bed10d73e3aac782bd9999a1e5a790932bfe9
```

# Software implementation of the RSA encryption algorithm
When designing digital circuits it is common to create a high level functional model. The following model is written at an extremely high level. It will produce correct results that can be used when generating test vectors for verification environments, but it does not provide any other value. It is expected that designers create more detailed models before attempting to write any RTL code. 



```python
# ------------------------------------------------------------------------------
# Function for encrypting messages
# key_e  : 256 bit integer representing the key e
# key_n  : 256 bit integer representing the key n
# M_array: Array of 256-bit messages.
# ------------------------------------------------------------------------------
def sw_encrypt(key_e, key_n, M_array):
  
  # Initialize the array where we will store the ciphertext
  C_array = []

  # Start the timer
  start_time = time.time()

  # Loop over all messages
  for M in M_array:
    # Encrypt the message by computing C = M**key_e mod key_n
    # The result is a 256-bit ciphertext  
    if(C_ENCR_ALGORITHM == C_ENCR_ALGORITHM_RSA):    
      C = pow(M, key_e, key_n)
    
    # Encrypt the message by computing C = M xor key_n    
    else:
      C = M ^ key_n
        
    C_array.append(C)

  # Stop the timer
  stop_time = time.time()
  sw_exec_time = stop_time-start_time
        
  return C_array, sw_exec_time

# ------------------------------------------------------------------------------
# Function for decrypting messages
# key_d  : 256 bit integer representing the key e
# key_n  : 256 bit integer representing the key n
# C_array: Array of 256-bit messages.
# ------------------------------------------------------------------------------
def sw_decrypt(key_d, key_n, C_array):
  # Decryption is the same function as encryption, just with different keys
  return sw_encrypt(key_d, key_n, C_array)

# ------------------------------------------------------------------------------
# Function for testing encryption and decryption in software
# ------------------------------------------------------------------------------
def test_sw_encryptdecrypt(key_e, key_d, key_n):
  M_arr_in = [0x0000000011111111222222223333333344444444555555556666666677777777,
              0x8888888899999999aaaaaaaabbbbbbbbccccccccddddddddeeeeeeeeffffffff]
  C_arr, sw_encr_time = sw_encrypt(key_e, key_n, M_arr_in)
  M_arr_out, sw_decr_time = sw_decrypt(key_d, key_n, C_arr)
  
  if(M_arr_in == M_arr_out):
    print("test_hw_encryptdecrypt: PASSED, encr_time: %f, decr_time: %f" % (sw_encr_time, sw_decr_time))    
  else:
    print("test_sw_encryptdecrypt: FAILED")   
  
# ------------------------------------------------------------------------------
# Test that the software implementation of encryption and decryption works
# ------------------------------------------------------------------------------
test_sw_encryptdecrypt(key_e, key_d, key_n)
  
```

    test_hw_encryptdecrypt: PASSED, encr_time: 0.000020, decr_time: 0.000012


# RSA encryption using an hardware accelerator

In the following code blocks, we test out the hardware RSA accelerator and measure it's performance.


```python
# ------------------------------------------------------------------------------
# Loading drivers for the direct memory access block (DMA) that is responsible
# for reading the messages from memory and pushing them into the RSA design.
# ------------------------------------------------------------------------------
from pynq import Overlay
import pynq.lib.dma

# Load the overlay
overlay = Overlay('/home/xilinx/pynq/overlays/rsa_soc/rsa_soc.bit')

# Load the RSA DMA
dma = overlay.rsa.rsa_dma

# Load the MMIO driver for the RSA accelerator
rsammio = overlay.rsa.rsa_acc.mmio

```




```python
# ------------------------------------------------------------------------------
# Function for writing C_BLOCKSIZE_IN_32_BIT_WORDS consequtive registers
# ------------------------------------------------------------------------------
def write_blockreg(address, block):
  reg_data = msg2word([block])
  addr = address
  # Each register contains 4 bytes. The registers are byte addressed.
  for data in reg_data:
    rsammio.write(addr, int(data))
    addr += 4

# ------------------------------------------------------------------------------
# Function for reading C_BLOCKSIZE_IN_32_BIT_WORDS consequtive registers
# ------------------------------------------------------------------------------
def read_blockreg(address):
  addr = address
  reg_arr = []
  for i in range(C_BLOCKSIZE_IN_32_BIT_WORDS):
    reg_arr.append(rsammio.read(addr))
    addr += 4
  reg_data = word2msg(reg_arr)[0]
  return reg_data
    
# ------------------------------------------------------------------------------
# Function for writing keys to the RSA accelerator
# ------------------------------------------------------------------------------
def write_keys(key_n, key_e_or_d):
  # Store N and E
  write_blockreg(0x00, key_n)
  write_blockreg(0x20, key_e_or_d)

# ------------------------------------------------------------------------------
# Function for reading keys from the RSA accelerator
# ------------------------------------------------------------------------------
def read_keys():
  # Read N, E
  n = read_blockreg(0x00)
  e_or_d = read_blockreg(0x20)
  return n, e_or_d

# ------------------------------------------------------------------------------
# Write the keys and read them back. Compare the result
# ------------------------------------------------------------------------------
def test_write_read_keys():
  write_keys(key_n, key_e)
  n, e = read_keys()
  if((key_n == n) and (key_e == e)):
    print("test_write_read_keys: PASSED")
  else:
    print("test_write_read_keys: FAILED")

# ------------------------------------------------------------------------------
# Test writing keys to the accelerator and reading back the keys
# ------------------------------------------------------------------------------
test_write_read_keys()
```

    test_write_read_keys: PASSED



```python
from pynq import Xlnk
import random
import numpy as np

# ------------------------------------------------------------------------------
# Function that computes C = M**e mode n 
# key_e  : 256 bit integer representing the key e
# key_n  : 256 bit integer representing the key n
# M_array: Array 256-bit blocks.
# ------------------------------------------------------------------------------
def hw_encrypt(key_e, key_n, M_array):

  # Write the keys
  write_keys(key_n, key_e)
            
  # Allocate buffers for the input and output signals. 
  M_word_array = msg2word(M_array)
  xlnk = Xlnk()
  buffer_size_in_words = len(M_word_array)    
  print("Buffer size:", buffer_size_in_words)

  # The size of the files must be aligned to the block size of 256 bit = 8*32 bit words
  assert buffer_size_in_words%C_BLOCKSIZE_IN_32_BIT_WORDS == 0, "The file size must be aligned to the block size of 256 bit" 
    
  in_buffer  = xlnk.cma_array(shape=(buffer_size_in_words,), dtype=np.uint32)
  out_buffer = xlnk.cma_array(shape=(buffer_size_in_words,), dtype=np.uint32)

  # Copy the samples to the in_buffer
  np.copyto(in_buffer, M_word_array)

  # Trigger the DMA transfer and wait for the result
  # Waiting for completeness is done trough polling of registers. Measurements of
  # consumed time will be more accurate with the use of interrupts.
  start_time = time.time()
  dma.sendchannel.transfer(in_buffer)
  dma.recvchannel.transfer(out_buffer)
  #print("DMA.sendchannel complete")
  #dma.sendchannel.wait()
    
  #print("DMA.recvchannel complete") 
  # Should be sufficient to wait for the recieve channel to complete. This 
  # will reduce some of the polling overhead when running tests.
  dma.recvchannel.wait()
  stop_time = time.time()
  hw_exec_time = stop_time-start_time

  # Copy the result  
  C_word_array = out_buffer.copy()
  C_array = word2msg(C_word_array)
  
  # Free the buffers
  in_buffer.close()
  out_buffer.close()

  # Return the result
  return C_array, hw_exec_time

# ------------------------------------------------------------------------------
# Function that computes M = C**d mode n
#
# Encryption and decryption is the same operation. Thus the hw_decrypt function
# is redundant.
# ------------------------------------------------------------------------------
def hw_decrypt(key_d, key_n, C_array):
  return hw_encrypt(key_d, key_n, C_array)

# ------------------------------------------------------------------------------
# Function for testing encryption and decryption in hardware
# ------------------------------------------------------------------------------
def test_hw_encryptdecrypt(key_e, key_d, key_n):
  M_arr_in = [0x0000000011111111222222223333333344444444555555556666666677777777,
              0x8888888899999999aaaaaaaabbbbbbbbccccccccddddddddeeeeeeeeffffffff]
  C_arr, hw_encr_time = hw_encrypt(key_e, key_n, M_arr_in)
  M_arr_out, hw_decr_time = hw_decrypt(key_d, key_n, C_arr)
  
  if(M_arr_in == M_arr_out):
    print("test_hw_encryptdecrypt: PASSED, encr_time: %f, decr_time: %f" % (hw_encr_time, hw_decr_time))
  else:
    print("test_hw_encryptdecrypt: FAILED")
    print("M_arr_in: ", hex(M_arr_in[0]))   
    print("C_arr: ", hex(C_arr[0]))             
    print("M_arr_out: ", hex(M_arr_out[0]))                       
  
# ------------------------------------------------------------------------------
# Test that the hardware implementation of encryption and decryption works
# ------------------------------------------------------------------------------
test_hw_encryptdecrypt(key_e, key_d, key_n)
```

    Buffer size: 16
    Buffer size: 16
    test_hw_encryptdecrypt: PASSED, encr_time: 0.000389, decr_time: 0.002695


# Encrypt and decrypt long messages in hardware and software

Results from encrypting and decrypting files in hardware and software.


```python
# ------------------------------------------------------------------------------
# Loop over all files encrypt/decrypt and store the results.
# ------------------------------------------------------------------------------
hw_runtime = []
sw_runtime = []

for i in range(num_testcases):
  direction, inp_file, otp_hw_file, otp_sw_file = get_testcase(i)
  print("*"*80)
  print("CRYPT DIR       : ", direction)
  print("INPUT FILE      : ", inp_file)
  print("OUTPUT FILE (HW): ", otp_hw_file)
  print("OUTPUT FILE (SW): ", otp_sw_file)
  if(C_ENCR_ALGORITHM == C_ENCR_ALGORITHM_RSA):
    print("ENCR ALGORITHM  : RSA")
  else: 
    print("ENCR ALGORITHM  : XOR")    
  print("*"*80)
  input_msg_data                   = word2msg(np.fromfile(str(inp_file),dtype=np.uint32))
  if(direction == "ENCR"):
    output_msg_hw_data, hw_exec_time = hw_encrypt(key_e, key_n, input_msg_data)
    hw_runtime.append(hw_exec_time)
    output_msg_sw_data, sw_exec_time = sw_encrypt(key_e, key_n, input_msg_data)
    sw_runtime.append(sw_exec_time)
    print("HW RUNTIME: ", hw_exec_time)    
    print("SW RUNTIME: ", sw_exec_time)    
  elif(direction == "DECR"):
    output_msg_hw_data, hw_exec_time = hw_decrypt(key_d, key_n, input_msg_data)
    hw_runtime.append(hw_exec_time)
    output_msg_sw_data, sw_exec_time = sw_decrypt(key_d, key_n, input_msg_data)
    sw_runtime.append(sw_exec_time)
    print("HW RUNTIME: ", hw_exec_time)    
    print("SW RUNTIME: ", sw_exec_time)    
    
  # Compare results
  if(output_msg_sw_data == output_msg_hw_data):
    print("HW and SW produced the same result: TEST PASSED")
  else:
    print("HW and SW output did not match: TEST FAILED")
  print()

  # Write the results to file
  msg2word(output_msg_hw_data).tofile(str(otp_hw_file))
  msg2word(output_msg_sw_data).tofile(str(otp_sw_file))    
    
    
```

    ********************************************************************************
    CRYPT DIR       :  ENCR
    INPUT FILE      :  /home/xilinx/pynq/crypto/xor/inp_messages/pt0_in.txt
    OUTPUT FILE (HW):  /home/xilinx/pynq/crypto/xor/otp_hw_messages/ct0_out.txt
    OUTPUT FILE (SW):  /home/xilinx/pynq/crypto/xor/otp_sw_messages/ct0_out.txt
    ENCR ALGORITHM  : XOR
    ********************************************************************************
    Buffer size: 504
    HW RUNTIME:  0.0018541812896728516
    SW RUNTIME:  0.00017976760864257812
    HW and SW produced the same result: TEST PASSED
    
    ********************************************************************************
    CRYPT DIR       :  ENCR
    INPUT FILE      :  /home/xilinx/pynq/crypto/xor/inp_messages/pt1_in.txt
    OUTPUT FILE (HW):  /home/xilinx/pynq/crypto/xor/otp_hw_messages/ct1_out.txt
    OUTPUT FILE (SW):  /home/xilinx/pynq/crypto/xor/otp_sw_messages/ct1_out.txt
    ENCR ALGORITHM  : XOR
    ********************************************************************************
    Buffer size: 7056
    HW RUNTIME:  0.0011360645294189453
    SW RUNTIME:  0.0028145313262939453
    HW and SW produced the same result: TEST PASSED
    
    ********************************************************************************
    CRYPT DIR       :  ENCR
    INPUT FILE      :  /home/xilinx/pynq/crypto/xor/inp_messages/pt2_in.txt
    OUTPUT FILE (HW):  /home/xilinx/pynq/crypto/xor/otp_hw_messages/ct2_out.txt
    OUTPUT FILE (SW):  /home/xilinx/pynq/crypto/xor/otp_sw_messages/ct2_out.txt
    ENCR ALGORITHM  : XOR
    ********************************************************************************
    Buffer size: 144
    HW RUNTIME:  0.0015401840209960938
    SW RUNTIME:  6.318092346191406e-05
    HW and SW produced the same result: TEST PASSED
    
    ********************************************************************************
    CRYPT DIR       :  DECR
    INPUT FILE      :  /home/xilinx/pynq/crypto/xor/inp_messages/ct3_in.txt
    OUTPUT FILE (HW):  /home/xilinx/pynq/crypto/xor/otp_hw_messages/pt3_out.txt
    OUTPUT FILE (SW):  /home/xilinx/pynq/crypto/xor/otp_sw_messages/pt3_out.txt
    ENCR ALGORITHM  : XOR
    ********************************************************************************
    Buffer size: 504
    HW RUNTIME:  0.0024080276489257812
    SW RUNTIME:  0.00018835067749023438
    HW and SW produced the same result: TEST PASSED
    
    ********************************************************************************
    CRYPT DIR       :  DECR
    INPUT FILE      :  /home/xilinx/pynq/crypto/xor/inp_messages/ct4_in.txt
    OUTPUT FILE (HW):  /home/xilinx/pynq/crypto/xor/otp_hw_messages/pt4_out.txt
    OUTPUT FILE (SW):  /home/xilinx/pynq/crypto/xor/otp_sw_messages/pt4_out.txt
    ENCR ALGORITHM  : XOR
    ********************************************************************************
    Buffer size: 7056
    HW RUNTIME:  0.0007059574127197266
    SW RUNTIME:  0.002298593521118164
    HW and SW produced the same result: TEST PASSED
    
    ********************************************************************************
    CRYPT DIR       :  DECR
    INPUT FILE      :  /home/xilinx/pynq/crypto/xor/inp_messages/ct5_in.txt
    OUTPUT FILE (HW):  /home/xilinx/pynq/crypto/xor/otp_hw_messages/pt5_out.txt
    OUTPUT FILE (SW):  /home/xilinx/pynq/crypto/xor/otp_sw_messages/pt5_out.txt
    ENCR ALGORITHM  : XOR
    ********************************************************************************
    Buffer size: 144
    HW RUNTIME:  0.0009644031524658203
    SW RUNTIME:  6.556510925292969e-05
    HW and SW produced the same result: TEST PASSED
    


# Plot results



```python
%matplotlib notebook
import matplotlib.pyplot as plt

if(C_ENCR_ALGORITHM == C_ENCR_ALGORITHM_RSA):
  ALGORITHM = "RSA"
else: 
  ALGORITHM = "XOR"
    
runtime_plot = plt.figure()
ax = plt.subplot(111)
hw_testcases = [i-0.1 for i in range (len(inp_files))]
sw_testcases = [i+0.1 for i in range (len(inp_files))]
plt.ylabel('Time (sec)')
plt.xlabel('Testcase')
ax.bar(hw_testcases, hw_runtime,width=0.2,color='b',align='center', label='HW %s RUNTIME' % ALGORITHM)
ax.bar(sw_testcases, sw_runtime,width=0.2,color='r',align='center', label='SW %s RUNTIME' % ALGORITHM)
plt.legend()
```


    <IPython.core.display.Javascript object>



<img src="data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAoAAAAHgCAYAAAA10dzkAAAgAElEQVR4nO3debwcZZn//W/IdkjIJkIgMQuByJLggigSQWBgkuD4A9kRRwlhNcoozEAgogYXmFEEN4QHVAJBCD488JMBgoxoIoMaMciiCSFANslhCZBAFrKQ6/nj7lN09+k+WequU1X3/Xm/XvWiU11dXee6uur+Ut1dLQEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAgEQXSYMl9WViYmJiYmIq1TRYbhwHttlgScbExMTExMRUymmwgO3QV5ItW7bMVq1axcTExMTExFSCadmyZW0BsG/OOQIl1VeSrVq1ygAAQDmsWrWKAIhUCIAAAJQMARBpEQABACgZAiDSIgACAFAyBECkRQAEELTNmzfbhg0bbN26dUxMpZk2bNhgmzdvbvq6JgAiLQIggGCtX7/eFi9ebPPmzWNiKt20ePFiW79+fcPXNgEQaREAAQTp7bfftqefftoWLlxoK1eutLVr1+Z+VoeJaWumtWvX2sqVK23hwoX29NNP29tvv93u9U0ARFoEQABBWrdunc2bN8/WrFmT96YA22XNmjU2b948W7duXbv7CIBIiwAIIEhtAbDR4AmUQUevYQIg0iIAAggSARBlRwBElgiAAIJEAETZEQCRJQIggCB1NHhKnTttq9NPP92OPfbYdvN/97vfmSR7/fXX7c0337Ru3brZ7bffXrPMKaecYpJs4cKFNfP33HNPu+SSSxo+33333Wfdu3e3uXPn1sy/6qqrbOedd7bW1tZk3tKlS23ixIm2++67W/fu3W3o0KH2b//2b7ZixYqaxx522GFtAcW6d+9uI0aMsEsuucTeeuutLf7tbY/r2rWrDRkyxM477zx77bXXapaTZHfffXe7x3/pS1+yww47rN36rrzyyprl7r77blOlOdXP2WxqW666L22PO/fcc9ttx6RJk0ySnX766Q3/tupp3LhxDWtBAESWCIAAghR6ADQz++hHP9oufAwcONCGDBliN954YzJv6dKlJskefPDBps955pln2qhRo5KA9ve//91aWlpsxowZyTLPPfec7brrrnbIIYfYrFmzbMmSJXb//ffbqFGjbOTIkfbqq68myx522GF29tlnW2trqy1ZssTuvPNO69OnT9MQWv23jx8/3lpbW23ZsmX261//2gYPHmynnnpqzXLahgDY0tJi/fv3rwmR1QFw5cqV1tramkyS7KabbqqZ17au+gA4ZMgQ69evn61duzaZv27dOuvfv78NHTq0XQBs+9uqp/pwW70eAiCyQgAEEKQYAuCll15qe++9d3L/vHnzrF+/fnbllVfaZz7zmWT+LbfcYj169OjwG9FvvPGGDRs2zCZPnmwbN260Aw880E466aSaZcaPH2/vec97asKOmVlra6v16tXLzjvvvGTeYYcdZl/60pdqljv++OPtgAMO2Oa//cILL7R3vetdNfO0DQHwk5/8pO2zzz520UUXJfOrA2C9ZutuFACPPfZYGz16tN16663J/F/84hf2vve9z4499th2AbBRX5shACJLBEAAQYohAD744IMmyZYvX25mZtdee639y7/8i82ZM8cGDx6cPO6MM86wQw45ZIvP+9BDD1m3bt3s5JNPtoEDB9a8rfvqq69aly5d7Iorrmj42LPPPtsGDBiQ/HpFfQB8/PHHbeDAgXbQQQdt09/+3HPP2X777WcDBw6sWU7bEACPPfZYu+uuu6ylpcWWLVtmZn4D4NVXX21HHnlkMv/II4+0a665hgCIQiMAxqSzRzEgR2UPgF27drXevXvXTC0tLTUBcM2aNdajRw+77bbbzMzspJNOsu985zu2ceNG22mnneyZZ54xM7M99tjDvvrVr27Vc5966qkmye64446a+X/605+aBiMzs6uvvtok2UsvvWRmLgB2797devfubT169DBJtsMOO9idd9651X97298rya6++uqa5ZptS7MAaObeMp84caKZ+Q2AL7/8svXs2dMWL15sixcvtpaWFnvllVcaBsBGff3GN77RcDsIgMgSATAmBEBEpOwB8KijjrKFCxfWTLfeemtNADQz+9jHPmbnnHOOmZntuuuu9uc//9nMzMaNG2c33HCDLVmyxCTZb3/72y0+7z/+8Q/r37+/9erVy774xS/W3NcWAO+6666Gj20UACdMmGALFy60uXPn2sknn2xnnnnmNv3tTzzxhJ1//vk2btw427hxY81y2o4AOHv2bOvatavNmzfPawA0c29vT5061b7+9a/bCSecYGbWMAA26mv1ZyerEQCRJQJgTAiAiEjZA+DWvAVsZnbZZZfZyJEj7W9/+5v16dPHNm3aZGZmV1xxhX3605+2adOmWUtLyxa/fWtmdvTRR9vhhx9us2bNsq5du9qsWbOS+1asWGFdunSxb3/72w0fu6W3gDds2GAjR460n/70p9v8tx9++OF22WWX1czr06ePTZs2reHjjznmmKbr+8QnPmHHHnus9wB477332vDhw2348OF23333mVnjAMhbwCgKAmBMCICISCwB8KGHHjJJNmXKFDv66KOT+Y888ogNGjTIJkyYYEccccQWn/PGG2+0nXbayZ5//nkzc2fSRowYYatXr06WGTt2rA0ePHi7vwRy00032W677dbu8Vv623/3u99ZS0uLvfDCC8m8D3/4w/aFL3yhZrnNmzfb6NGja77sUb++J5980nbYYQe7+OKLvQbATZs22aBBg2zw4MFJCCcAosgIgDEhACIisQTAdevWWc+ePa1Pnz72n//5n8n8DRs2WK9evaxPnz5NP2PWZvHixdanTx+7/vrrk3lr1qyxvfbaq+at4Geeecbe/e5326GHHmqzZ8+2pUuX2syZM2306NENLwNTHwDXr19vu+++u333u9/d5r/9gAMOqAl8d9xxh/Xs2dN+9KMf2YIFC+zxxx+3SZMmWa9evWzx4sUdru+zn/1s8vnCRrQdAdDMhbLq8bRRAGx0GZhXXnml4XYQAJElAmBMCICISCwB0Oydiy7/6U9/qpl/5JFHmiR7+OGHmz7X5s2b7cgjj7SxY8e2u+/hhx9u91bw4sWLbcKECbbbbrtZ9+7dbciQIXb++ec3vBB0fQA0M/v2t79tu+yyS82Zxa3523/xi19Yz549benSpcm8GTNm2IEHHmh9+/a1XXfd1caNG2d/+ctftri+RYsWJV9MaUTbGQDrNQqAUvsLQVdfyqcaARBZIgDGhACIiPBTcCg7AiCyRACMCQEQESEAouwIgMgSATAmBEBEhACIsiMAIksEwJgQABERAiDKjgCILBEAY0IAREQIgCg7AiCyRACMCQEQESEAouwIgMgSATAmBEBEhACIsiMAIksEwJgQABERAiDKjgCILBEAY0IAREQIgCg7AiCyRACMCQEQESEAouwIgMgSATAmBEBEhACIsiMAIksEwJgQABGRDgNg2n0h433npZdesnPOOceGDBliPXr0sIEDB9rYsWPtD3/4g5mZnXLKKTZu3Liax8ycOdMk2Ve+8pWa+d/85jdt9913b/g8q1evthEjRtgFF1xQM3/RokXWp08fu+GGG5J5mzZtsquvvtr2339/69mzp/Xr18/Gjx9v//u//1vz2JtuuqktmJgk23XXXe2Tn/yk/e1vf+vwb277neO26V3vepcdccQR7dbf7Pd3//rXv5okW7RoUc369ttvP9u0aVPNsv369bObbrqp3XM2mqqXa/sN5rZ/9+/fv93r689//nPy2GZ/W/XU2tratCYEQGSJABgTAiAiUuYAeMghh9hBBx1kv/3tb23x4sU2Z84cu+KKK+zee+81M7Prr7/edtppJ9u4cWPymIsvvtiGDBliH/vYx2rW9U//9E922mmnNX2u2bNnW7du3ez3v/+9mZlt3rzZDj/8cBs/fnyyzObNm+3EE0+0/v3724033mjPP/+8Pf7443b22Wdbt27d7O67706Wvemmm6xv377W2tpqy5cvt0cffdSOOOIIGzZsmK1fv77pdrSFpAULFlhra6s9+eSTdvLJJ1u/fv3spZdeSpbb1gDY0tJiP//5z2uWbQuA69evt9bW1mQ6+eSTbfz48TXz1q5d2zQADhkyxG677baadZ977rk2dOjQhgGw7W+rnt5+++2mNSEAIksEwJgQABGRsgbA119/3STZrFmzmi6zYMECk2R//OMfk3kf+chH7Nprr7UePXrYmjVrzMxs/fr1tuOOO9qNN97Y4XNecMEFtueee9rq1avtmmuusf79+9s//vGP5P4ZM2aYJLvnnnvaPfb444+3nXfe2VavXm1mLgD269evZpl77rnHJNmTTz7ZdBvqQ5aZ2ZNPPtnuebc1AF500UU2ZMgQe+utt5Jl2wJgvWbrbhYAL7vsMjvqqKOS5dauXWv9+vWzr371qw0DYPXftjUIgMgSATAmBEBEpKwBcOPGjbbTTjvZl7/85ZrQUm/QoEF2xRVXmJnZG2+8Yd26dbOXX37Z9t13X3vwwQfNzJ3dk2TPPvtsh8+5du1a23vvve1Tn/qU7bjjjjZ9+vSa+4855hh773vf2/CxjzzyiElKzgLWB8DXX3/dTj31VJNk8+fPb7oN9SFpzZo1duGFF5okmzlzZrLctgbAF154wXbffXf77ne/myzrKwAuWLDAevbsaUuWLDEzs+nTp9v73/9+u/vuuwmAKDwCYEwIgIhIWQOgmdmdd95pAwYMsJaWFhszZoxdeuml9sQTT9Qs85nPfMbGjh1rZmb33Xef7bfffmZmdt5559mUKVPMzOzyyy+3IUOGbNVzPvDAAybJjj766Hb37bPPPg2DkZnZa6+9ZpLsv/7rv8zsnc8A9u7d23r16tUWUuyYY47p8PnbQlLv3r2td+/e1qVLF5NkH/rQh2zDhg3JctsaAF9//XW7/vrr7V3vepetXLnSzPwFwNdff90+9alP2eWXX25mZkcccYT94Ac/aBoA2/62tqlZqG5DAESWCIAxIQAiImUOgG3b/+CDD9rll19uBx98sHXt2rUmtNx4443Wu3dv27Bhg1100UU2adIkMzO7/fbbbcyYMWbmAsnnPve5rXq+k046yXr16mXvec97kqDUZp999mka4BoFwD59+tjChQtt/vz5dv3119uee+5py5cv7/D520LSY489ZgsWLLAZM2bYsGHD7KmnnqpZbnsC4MaNG23kyJF26aWXmpnfAHjPPffYHnvsYc8995y1tLTYihUrmgbAxx57zBYuXJhMbdvaDAEQWSIAxoQAiIiUPQDWO/PMM23o0KHJv5999lmTZI888ogdeOCBdscdd5iZ2fLly6179+726quvWktLi02bNm2L654xY4a1tLTYY489ZqNGjbIzzjij5v5jjjnGRo4c2fCxW3oL2Mxs6tSpduihh3a4DY3eJp02bZrttddeNW+Fn3/++Xb44Yc3ffxrr73WcH2//OUvrVevXvbCCy94DYAbN2603XbbzQ4//HA76aSTzMx4CxilQACMSQEGMaCzhBYAv/e979nOO+9cM2/IkCE2efJk69atm7344ovJ/JEjR9qUKVNMUvL5tGZefPFF23nnnZPPyD366KPWrVs3u//++5NlbrvtNpO2/0sgq1atsr59+9pdd93VdDsahaS3337bRowYYVdffXUy79prr7V3v/vdtnbt2prHf/e737Vddtmlw/V9+MMftnPOOcdrADRz38CW3vmsIgEQZUAAjEkBBjGg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" width="640">





    <matplotlib.legend.Legend at 0xaee260d0>



# Discussion of results

## Discussion of XOR results
The overhead for running the HW encryption is relatively large. For small tests, such as 0,2,3 and 5, the performance of the HW solution is low compared to the SW solution. For the HW polling of registers is used for detecting when the encryption/decryption is completed. An improvement that will reduce the overhead is to implement support for interrupts.

Tests 1 and 4 are longer and here the HW is clearly faster than the SW solution since the overhead is no longer dominating the runtime of the HW.

## Discussion of RSA results
RSA is a much more demainding algorithm and should run slowly in software for most tests compared to the HW. 
