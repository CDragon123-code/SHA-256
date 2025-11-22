# Custom ASIC Design for SHA-256

A custom ASIC hardware accelerator for the SHA-256 algorithm entirely created using open-source electronic design automation tools. The IC was synthesized in SkyWater Foundries’ SKY130 130nm process technology through OpenLANE automated RTL to GDSII flow. The final design is compatible with 32-bit microcontrollers, has a total area of 104,585µm², and operates at a maximum clock frequency of 97.89MHz.

<p align="center">
<img src="https://github.com/LDFranck/SHA-256/blob/main/exploratory/final_run/layout.png?raw=true"/>
</p>

## Publication
Explore the [full article here](https://doi.org/10.3390/computers13010009) for in-depth insights:

```
@Article{computers13010009,
  AUTHOR = {Franck, Lucas Daudt and Ginja, Gabriel Augusto and Carmo, João Paulo and Afonso, José A. and Luppe, Maximiliam},
  TITLE = {Custom ASIC Design for SHA-256 Using Open-Source Tools},
  JOURNAL = {Computers},
  VOLUME = {13},
  YEAR = {2024},
  NUMBER = {1},
  ARTICLE-NUMBER = {9},
  URL = {https://www.mdpi.com/2073-431X/13/1/9},
  ISSN = {2073-431X},
  DOI = {10.3390/computers13010009}
}
```

## Verilog Description & Testbench
The SHA-256 cryptographic hardware accelerator HDL files are available in the [Verilog](/Verilog) folder. The `SHA256.v` file is the top-level module that instantiates all subblocks. Take a look!
> :information_source: **Additional Information:**\
> All hardware structures are well described in the publication. Consider checking there for further clarification.

\
**Wanna test it? Sure!** \
Grab your favorite Verilog compiler and run the fully automated testbench `SHA256_testbench.v`. This file will test the design against an input/output defined at `tb_data.txt`. Feel free to change the data for whatever you want, just remember to format it accordingly!
> **:warning: Warning:**\
> The testbench file was built to accept only data formatted as shown in `tb_data.txt`. The available example shows a 2-block binary message and its respective output hash. It's highly recommended to use [SHA256 Algorithm Explained](https://sha256algorithm.com/) website to generate your test data.

\
**You don't have a Verilog compiler?**\
A very practical open-source Verilog compiler available is [Icarus Verilog](https://github.com/steveicarus/iverilog). The best part is that you can easily integrate it with [GTKWave](https://github.com/gtkwave/gtkwave) to visualize waveforms. Follow this [YouTube Tutorial](https://www.youtube.com/watch?v=SzYluleCDEM) to install and set up the environment.
> **:warning: Warning:**\
> Don't forget to add the commands shown in the video after `initial begin` statement of `SHA256_testbench.v` to make it work with GTKWave!

## Exploratory Analysis Data
All data generated and used throughout the exploratory studies is available in the [exploratory](/exploratory) folder. The OpenLANE configuration files and parameter matrices have also been added to facilitate reproducibility.

## OpenLANE (deprecated)
The [OpenLANE](https://github.com/The-OpenROAD-Project/OpenLane) project is a fully open-source RTL to GDSII automated ASIC design flow. Their software is relatively easy to install and use, and you can find all the necessary information in the [official documentation](https://openlane.readthedocs.io/en).

If you decide to run OpenLANE on a remote server, you may want to try the following scripts to make your life easier:
> :information_source: **Additional Information:**\
> The installation scripts will create a new user called `openlane` with the password `openlane123` and set up Docker to run the OpenLANE container. Please change the account password after finishing for safety.
```
ssh root@<server_ip>
```
``` 
curl -s https://raw.githubusercontent.com/LDFranck/SHA-256/main/scripts/setupUser.sh | bash
```
```
ssh openlane@<server_ip>
```
```
curl -s https://raw.githubusercontent.com/LDFranck/SHA-256/main/scripts/setupDocker.sh | sudo bash
```
```
sudo su - openlane
```
```
cd $HOME
git clone https://github.com/The-OpenROAD-Project/OpenLane
cd OpenLane/
make
make test
```
> **:warning: Warning:**\
> The OpenLANE project is updated on a weekly basis, and the previous scripts might be outdated. If the provided test case happens to fail, restart your server and follow the installation instructions available on their GitHub.
