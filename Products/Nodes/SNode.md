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
| SFS |   Sap Flow Sensor  |     |
| DBV60 |   Band Dendrometer - SDI-12  |     |
| DPS40 |   Pivot Dendrometer - SDI-12  |     |
| SMT100D |  Soil Moisture Sensors   |     |
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
The S-Node is available as either a:
- LoRaWAN node, supplied with either EU868 (Europe), AU915 (Australia), US915 (United States), or AS923 (Asia) frequency plans depending on customer requirements.
- Cellular (CAT-M1/NB-IoT) node

The S-Node is an Internet of Things (IoT) node that is used for the measurement of up to:
- 2x single ended voltage inputs
- 1x 4-20mA input
- 2x Thermistor Input
- 4x Digital Inputs
Available as a **6B (6,000mAh)** or **13b (13,999mAh)** version that will be combined with a matched solar panel (10 watt with the **6B** and 20 watt with the **13B**), the S-Node is a versatile SDI-12 IoT node.

## Functional description

The S-Node measures voltage, current, and counter inputs using a 24-bit ADC.

### Inputs: Sensor
- SDI-12


### Outputs: Data

The data is output as a single hexadecimal payload, containing all the input variables.

The hexadecimal data requires a decoder at the LoRaWAN Server.

Specific decoders can be found on the ICT International GitHub library.

# Components (what's in the box)
----

Included with the S-Node are:

- **6B** OR **13B** battery
- antenna to suit

## Optional features

Options include:

- Node mounting bracket, suitable for poles up to 60 mm in diameter
- Additional sensors

## USB cables

To access the node for configuration, a USB 2.0 Type B cable is required (not included).

## Config Tool

The S-Node is shipped pre-configured, ready to go.

Certain LoRaWAN parameters can be changed using Over-The-Air configuration.

# Unpacking
The node will be shipped with the sensors connected directly to the node.
If the node mounting bracket has been optioned, the node will be attached to the bracket. 

> [!CAUTION]
> - ESD protection
> - Only power the node on once the antenna is attached
> - Once sensors are connected, confirm polarity before turning the power on.

The node board is protected with a conformal coating, which reduces the risk of Electrostatic Discharge (ESD).

# Preparing the S-Node for use
----
> [!CAUTION] 
> - Do not change any of the LoRaWAN key settings unless you are changing the gateway connection of the device. 
> - Changes made to LoRaWAN keys will require reprogramming at the LoRaWAN Server 

> [!IMPORTANT]
> **Site Selection:**
> <br>When choosing the site for the device installation, consideration must be given to:
> - Gateway location
> - Node positioning
> - Antenna orientation
> - Obstructions between the node and gateway



## Installation location

The installation location of the S-Node is determined by:

- Signal strength
- Sensor positions
- Cable lengths

### Positioning of the S-Node

Position the S-Node towards the LoRaWAN gateway to optimise the signal.

Ensure that there are no obstructions within the following distances:

| **LoRaWAN Frequency** | **Whole wavelength in centimetres** | **Minimum distance to obstruction** |
| :--- | :---: | :---: |
| EU868 (Europe) | 34.5 | 17 cm |
| AU915 (Australia) | 32.7 | 16 cm |
| US915 (United States) | 32.7 | 16 cm |
| AS923 (Asia) | 32.4 | 16 cm |

### Mounting the S-Node
<pre>
Included with the S-Node are 4 brackets that can be screwed to the rear of the node enclosure,
using the moulded holes in the corners. These can be used to mount the node enclosure to a suitable
wall or post.
</pre>
## Powering the device

The S-Node 

~~is a self-powered device with 3x AA batteries. It is recommended to use 1.5-volt lithium batteries when replacements are needed. The supplied AA batteries are L91 Energizer single use batteries, mAh, 1.5 volt.~~

To power the device on, move the switch to the ON position.

The unit will start to transmit at the logging interval from the moment it is powered on. This is confirmed by the LED light sequence:

<mark>Red, blue sparkles</mark>

## Connecting sensors

<mark>The S-Node is supplied with sensors connected. If the sensors need to be disconnected (e.g. for running cables through conduit) then the following needs to be followed.
<br>
Each connector in the enclosure is almost tool-less for installation, with a push to fit connector.
<br>
To release the cable, a jeweller's flat head screwdriver is required.
</mark>

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