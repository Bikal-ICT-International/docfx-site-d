# About this document
----
## Version information

| Document code/Version | Date | Description |
| :-- | :-- | :-- |
|   |   |   |
|   |   |   |

## Related manuals

| **Product Code** | **Product Name** | **Brief description** |
| --- | --- | --- |
|  |     |     |
|  |     |     |
|  |     |     |
|  |     |     |
|  |     |     |
|  |     |     |

## Documentation conventions

> [!WARNING]
> Dangerous certain consequences of an action.

> [!CAUTION]
> <br>Negative potential consequences of an action.

> [!IMPORTANT]
> <br>Essential information required for user success.

> [!NOTE]
> <br>Information the user should notice even if skimming.

> [!TIP]
> <br>Optional information to help a user be more successful.

# Product overview
----

The Psychrometer is 



## Functional description



### Inputs: Sensor


# Components (what's in the box)
----

Included with the 

## Optional features

Options include:

- 

## USB cables

## Installation Kit
Plain Text


## Config Tool

Plain text

## Backward compatibility
Plain text

## ESD Protection
> [!CAUTION]
> - Negative potential consequences of an action.

Plain Text


# Funtional Description
Plain Text

## Measurement principle
Plain Text

## Inputs
Plain text

## Outputs
Plain text

# Installation
Plain text
> [!TIP] 
> - Optional information to help a user be more successful.

## Site Selection
Plain text

## Unpacking
Plain text

## Installing
Plain text

## Placing
Plain text

## Mounting
Plain text

## Aligning
Plain text

## Configuring offset
Plain text

## Installing Configuration Tool
Plain Text

## Installing USB cable driver
Plain text

# Powering the sensor/ instrument/ device
Plain text

## Power supplies
Plain text

## Power management
Plain text

## Wiring
Plain text

## Solar
Plain text

# Connections
Plain text

## Comm options
Plain text

## Comm protocols
Plain text

## Connection cables
Plain text

## Communications Settings
Plain text

# Commands
Plain text

## SDI-12 
Plain text 

## RS-485 
Plain text 

## Analogue 
Plain text 

# Settings 
Plain text 

## Checking the settings 
Plain text 

## Setting fields 
Plain text 

## Changing the settings 
Plain text 

# Maintenance 
Plain text 

## Cleaning 
Plain text 

## Calibration 
Plain text 

# Troubleshooting 
Plain text 

## Error messaging 
Plain text 

## Missing readings and error indication 
Plain text 

# Technical specifications 
Plain text 

## Specifications 
Plain text 

## Options and accessories 
Plain text 

# Networking 
Plain text 

## Connecting several sensors 
Plain text 

## SDI-12 
Plain text 

## RS-485 
Plain text 

## Analogue 
Plain text 

## Decoder 
Plain text 

# External sensors 
Plain text 

## Complimenting sensors 
Plain text 

 








 not change any of the LoRaWAN key settings unless you are changing the gateway connection of the device. 
> - Changes made to LoRaWAN keys will require reprogramming at the LoRaWAN Server 

> [!IMPORTANT]
> **Site Selection:**
> <br>When choosing the site for the device installation, consideration must be given to:
> - Gateway location
> - Node positioning
> - Antenna orientation
> - Obstructions between the node and gateway



## Installation location

The installation location of the AD-Node is determined by:

- Signal strength
- Sensor positions
- Cable lengths

### Positioning of the AD-Node

Position the AD-Node towards the LoRaWAN gateway to optimise the signal.

Ensure that there are no obstructions within the following distances:

| **LoRaWAN Frequency** | **Whole wavelength in centimetres** | **Minimum distance to obstruction** |
| :--- | :---: | :---: |
| EU868 (Europe) | 34.5 | 17 cm |
| AU915 (Australia) | 32.7 | 16 cm |
| US915 (United States) | 32.7 | 16 cm |
| AS923 (Asia) | 32.4 | 16 cm |

### Mounting the AD-Node
<pre>
Included with the AD-Node are 4 brackets that can be screwed to the rear of the node enclosure, 

using the moulded holes in the corners. These can be used to mount the node enclosure to a suitable
wall or post.
</pre>
## Powering the device

The AD-Node is a self-powered device with 3x AA batteries. It is recommended to use 1.5-volt lithium batteries when replacements are needed. The supplied AA batteries are L91 Energizer single use batteries, mAh, 1.5 volt.

To power the device on, move the switch to the On position.

The unit will start to transmit at the logging interval from the moment it is powered on. This is confirmed by the LED light sequence:

Red, blue sparkles

## Connecting sensors

The AD-Node is supplied with sensors connected. If the sensors need to be disconnected (e.g. for running cables through conduit) then the following needs to be followed.

Each connector in the enclosure is almost tool-less for installation, with a push to fit connector.

To release the cable, a jeweller's flat head screwdriver is required.

# Configuration Changes
-----

## Communication Settings

Any changes that are needed to be made, such as measurement frequency, can be made using the node terminal function.

Node Terminal is downloadable from:

### Checking the settings

Settings can be checked using Node Terminal

> [!CAUTION]
> - Do not change any of the LoRaWAN key settings unless you are changing the gateway connection of the device.
> - Changes made to LoRaWAN keys will require reprogramming at the LoRaWAN Server

### Setting LoRaWAN fields

The settings fields that can be changed are:
- LoRaWAN Keys
- Sensor/Measurement Settings

### Changing the LoRa settings

To retrieve or reprogram LoRaWAN keys (OTAA), enter the following:

| To Retrieve: | To Reprogram: |
| :--- | :--- |
| lora eui dev | lora eui dev 0011223344556677 |
| lora eui app | lora eui app 0011223344556677 |
| lora key app | lora key app 00112233445566778899887766554433 |


<table style="width:70%; text-align:left;">
  <colgroup>
    <col style="width:%">
    <col style="width:%">
  </colgroup>
  <thead>
    <tr>
      <th>To Retrieve:</th>
      <th>To Reprogram:</th>
    </tr>
  </thead>
  <tbody>
    <tr>
      <td>lora eui dev</td>
      <td>lora eui dev 0011223344556677</td>
    </tr>
    <tr>
      <td>lora eui app</td>
      <td>lora eui app 0011223344556677</td>
    </tr>
    <tr>
      <td>lora key app</td>
      <td>lora key app 00112233445566778899887766554433</td>
     </tr>
  </tbody>
</table>


## Sensor Settings

### Changing the measurement frequency

The upload schedule can be changed using the command report period. By default the system will be shipped at a 10-minute logging interval (600).

e.g. changing to a 15-minute interval would use the following code:

report period 900

### Analogue Configuration

Analogue measurements can be post-processed in the cloud

# Maintenance
----
Maintenance is at the sensor level, rather than the device level.

The batteries are replaceable. To replace follow the steps below:

- Open the enclosure
- Turn the power off by moving the switch to the 1 position
- Release the battery retaining strap
- Remove the batteries
- Check the polarity of the new batteries
- Insert the batteries
- Replace the retaining strap
- Turn the device switch to the On position
- Clean the rubber seal and opposite surface
- Close the enclosure, and ensure that both latches are fully closed

## Calibration

There is no calibration of the device available.

Calibration is undertaken on a sensor-by-sensor basis.

# Troubleshooting
----
Plain text

## Error messaging

Plain text

## Missing readings and error indication

Plain text

# Technical specifications
----
_All technical specifications are subject to change as the products undergo continuous improvement_

## Specifications

|     | Detail |
| --- | --- |
| Analogue | Analogue inputs with selectable voltage<br><br>0 - 12v Input Range<br><br>4x Single Ended or 2x Differential |
| Digital | Digital inputs with pulse counting<br><br>Up to 1kHz input frequency |
| Operating Environment | -20°C to 60°C |
| Enclosure Dimensions: | IP65 Clam-Shell 140 ×120 ×80 mm, 500 g |
| Certifications: | AS/NZS 60950.1:2011<br><br>AS/NZS 4268:2012<br><br>RoHS compliant (lead-free) |

## Options and accessories

Plain text

## Compatible sensors

| **Product Code** | **Product Name** | **Maximum possible number\*** |
| --- | --- | --- |
| MP406 |     |     |
| DBV60 |     |     |
| DPV40 |     |     |
| SMT100a |     |     |
| Therm-EP |     |     |
| PRP-02 |     |     |

\* this is the maximum number of that sensor that can on an individual node. Combinations will be different.