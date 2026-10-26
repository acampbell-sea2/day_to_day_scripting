# Setting up script(s)

1. To install or set up the script, first copy the text from Github (here).
2. Copy and paste to your favorite text editor or notepad. Save it (remember the path it is saved at, as you will need this bring the script into your WSL Ubuntu instance.
3. There are two fairly simple methods for importing the code into Linux:  
   3.1 **Preferred:** Run `cp -i "/mnt/c/Users/acampbell/Downloads/get_gpu_node_file.sh" "/home/acampbell/scripts/"`  
      3.1.1 Be sure and change username and paths to match what your desired paths  
   3.2 Run `vim get_gpu_node_file.sh` *(You can enter the full path where you want to the file to be written to, or you can run the `vim` command in the directory that you wish to have the file created in)* to open VIM and manually write your script
4. Once the script is in your desired location, run `cd /home/acampbell/scripts` (Change to your path) to navigate to your script directory. Use `chmod u+x get_gpu_node_file.sh` to make the script executable, and lastly confirm using `ls -l`.  
5. Run the script  
   5.1 Navigate to the script directory `cd /home/acampbell/scripts` **(Change to your path)**  
   5.2 If its a bash script, run it using `./get_gpu_node_file.sh`
   
# Information about the script
If you use `nslookup` on any of the nodes, it returns `node_name.o1.local` for all the nodes. So this is hard-coded into the script. When prompted for the GPU_NODE, you don't need to add the domain, since it appends it your input.  

The script uses the DCOPs and Jumpbox hops to connect to the OS via ssh. So, make sure that your linux instance has an SSH key for DCOPs and you know the password for the `ubuntu@10.1.11.117` hop.

Otherwise, its pretty simple to use.

-Andrew




