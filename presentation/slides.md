<!-- 
View here: (?)
https://htmlpreview.github.io/?https://raw.githubusercontent.com/pburkholder/PsArmResources/master/presentation/slides/index.html#/>

Can't decide between https://github.com/jedcn/reveal-ck or https://github.com/webpro/reveal-md
-->

---

# Azure Code-Driven Infrastructure

* A word about Azure
* The way of Portal
* The way of suffering
* The way of Posh
* The testable way

---

<section data-background="https://secure.aadcdn.microsoftonline-p.com/ests/2.1.5898.9/content/images/default_signin_illustration.png"/>

# <br>
# <br>
# Azure

---

## Reference Architecture

<img src="https://docs.microsoft.com/en-us/azure/virtual-network/media/virtual-network-get-started-vnet-subnet/vnet-diagram.png" alt="My First VNet" style="width: 100%;"/>

```note
https://docs.microsoft.com/en-us/azure/virtual-network/virtual-network-get-started-vnet-subnet
```

Note:
https://docs.microsoft.com/en-us/azure/virtual-network/virtual-network-get-started-vnet-subnet

---

<section data-background-image="images/portal.gif"/> 

# <br>
# <br>
# The Portal Way

```note
ffmpeg -i in.mov -s 600x400 -pix_fmt rgb24 -r 10 -f gif - | gifsicle --optimize=3 --delay=10 > out.gif
from 
https://gist.github.com/dergachev/4627207
```

***

# The way of JSON

---



```bash
brew cask install powershell
powershell
```

---

```
# Get the AzureRM .NET core 0.3.4 preview
Install-Module AzureRM.NetCore.Preview
Import-Module AzureRM.NetCore.Preview
Install-Module AzureRM -MinimumVersion 3.8.0 -Scope CurrentUser
```

---

<section data-background="http://static.guim.co.uk/sys-images/Arts/Arts_/Pictures/2015/2/18/1424262922461/Exodus-II-Dubai-UAE-2010--001.jpg"/>


<!-- .slide: data-background="http://static.guim.co.uk/sys-images/Arts/Arts_/Pictures/2015/2/18/1424262922461/Exodus-II-Dubai-UAE-2010--001.jpg" -->


# Infrastructure

---

PowerShell AzureRM on OsX or Linux is very limited at this time because the underlying .NET libraries are pretty limited. You _can_ login and do some basic calls against resources, but not much else. See for more: https://github.com/Azure/azure-powershell/issues/3178
and https://github.com/Azure/azure-powershell/issues/3746 - June 2017 milestone.

---

# Welcome

---

## Superb Tables

Item          | Value         | Quantity
------------- | ------------- | ---------
Apples        | $1            |       18
Lemonade      | $2            |       20
Bread         | $3.50         |        2

---

# Thank You
