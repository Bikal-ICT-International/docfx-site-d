# Information Resources for new Datalogger/Node Platform (DNP)

## DNP information

*Datalogger first with integrated IoT communication options. Robust data collection and storage is prioritised, along with user-friendly installation and configuration.*

The node has multiple inputs that allow for:

- Easy to use SDI-12 and RS485 connections with:
  - 8x SDI-12 inputs
  - 4x RS485 inputs (and therefore outputs as well that are suitable for control systems)
  - 3x Voltage inputs, capable of 4-20mA and differential measurements
- 1x digital counter (compatible with double reed switch rain gauges)
- Expansion options that allow for single cable expansion using additional measurement modules
  - CANBUS
  - Single Pair

The enclosure has been designed to be as easy to use as possible and for simple installation and includes simple pole mount bracket that allows for easy installation. By using pre-wired connectors, all sensors become plug and play. The datalogger has:

- 4x SDI-12 Connectors, each capable of connecting two sensors
- 2x RS485, each capable of connecting two sensors
- 3x Voltage Connectors
- 1x Digital
- 1x 3 Pin power (solar or benchtop)
- 1x CANBUS

With power provided to the node by either a rechargeable battery and solar panel with either 10, 20 or 40W solar panel options, or benchtop power options for laboratory installations (retaining the internal battery, creating a mini-UPS equipped logger), the node is easy to install without any specialised skills.

With an option to connect an extra solar panel, as well as three sizes of internal rechargeable batteries, the power system is designed to be robust, reliable and adaptable.

Whilst designed as a datalogging platform first, the communication options allow for installation in many remote locations.

## New Communication Options

The new node will be available with the following communication options:

- Point to Point WiFi and Bluetooth for configuration/short range data access
- LoRaWAN: All common bands
- Cellular
- Satellite:
  - Iridium SMT internal
  - Iridium CERTUS 100 (via ethernet and external module)

Combined with the ICT International DB2 platform, designed for the visualisation and storage of timeseries data related to soil, plant, and environmental measurements, the Node is a powerful measurement tool for many applications.

## Key Features and Benefits

| Feature | Benefit |
| :--- | :--- |
| **SDI-12** | - Designed with 4x ports, each supporting 2 SDI-12 input busses  \n- Port-level addressing removes the need to address sensors in many applications  \n- Individually controlled power to each SDI-12 input  \n- Independent functionality  \n- Improved independence if sensor fails  \n- Faster configuration  \n- No need to address sensors |
| **RS485** | - Designed with 2x ports each supporting 2x RS485 channels  \n- Individually controlled power to each port  \n- Ability to control (transmit commands) other systems  \n- Independent functionality and improved independence if sensor fails  \n- Faster configuration, no need to address sensors  \n- Compatibility with other RTUs and control systems |
| **Digital** | - Compatible with double reed switch rain gauges |
| **Voltage** | - Differential measurements |
| **4-20mA** | - Available with 24-volt power |

## Technical details New Node/Sensor Package Build List

All tiers for the multiple sensor option would comprise the following:

- Logger: the new Definium Logger, including mounting system
  - Main Board with SD Card Storage
  - Input Connectors
    - 2x RS485
    - 4x SDI-12
    - 3x Voltage
    - 1x Digital
    - 1x 3 pin Power
    - 1x CANBUS
  - Takachi Enclosure with mounting bracket
    - Enclosure WG15-21-9W
    - Mounting Bracket: WPMB-M4-2 G
    - Gore-Tex Vent
- Battery, Solar Panel, and mounting system to suit:
  - Low power (LP) using 10W solar and 6B battery
    - 10-Watt Solar Panel
      - Cable
      - Connector
    - 6B Battery
    - Mount (RF Industries Mount)
  - High Power (HP) using 20W solar and 13B battery
    - 20-Watt Solar Panel
      - Cable
      - Connector
    - 13B Battery
    - Mount (RF Industries Mount)
  - Ultra-High Power (UHP) using 40W solar and 26B battery
    - 40-Watt Solar Panel
      - Cable
      - Connector
    - 26B Battery
    - Mount (RF Industries Mount)
  - Extra Power (EP-L/-H/-U)
    - 2nd matched solar panel
      - Cable
      - Connector
      - Diodes
    - Mount to suit
- Mounting system for Sensors (Crossarm) when included
- All connectors and wiring for the sensors

For those that require data connectivity, then there would be the option to include:

- LoRaWAN (-L)
  - Comms board
  - Antenna
  - Integration to TTN
  - Decoder
- Cat-M1 (-C)
  - Comms Module
  - Antenna
  - 1NCE SIM Card
  - Integration to MQTT broker
  - Decoder
- 3G/4G/5G (-G)
  - Comms Module
  - Antenna
  - Integration to MQTT broker
  - Decoder
  - *Locally sourced SIM Card*
- Satellite (-S)
  - Comms Module
  - Antenna
  - Subscription for GroundControl IMT
  - Integration to MQTT broker
  - Decoder

## Datalogger/Node Platform outside of the packages

When configuring a Standalone ICT International DNP, the following options need to be considered:

- Communications
  - DNP-D: Datalogger only, no IoT Comms
  - DNP-L: LoRaWAN (BOM)
  - DNP-C: Cellular (BOM)
  - DNP-S: Internal Satellite Module (BOM)
- Power Options for DNP
  - LP: Low Power with 6,000mAh battery, 10W solar and mount suit (BOM)
  - HP: High Power with 13,000mAh battery, 20W solar and mount suit (BOM)
  - UHP: Ultra-high power with 26,000mAh battery, 40W solar and mount suit (BOM)
  - Extra Power (EP-LP/-HP/-UHP) comprising a 2nd matched solar panel with: (BOMx3)
    - Cable
    - Connector
    - Diodes
    - Mount to suit

## Dashboard and Databasing for the new combinations

By moving to a standardised set of measurement bundles the construction of dashboards for customers will be much simplified and more scalable as an implementation solution. Each measurement bundle will require a maximum of three dashboards; however, all the parameters are very similar in the data type that will come in. Dashboards can be combined with additional modules to enhance the data collected. These modules are (generally) specific to single sensor (type) measurements on a single node or CANBUS expansion.

| Measurement Bundle | Dashboard or Module |
| :--- | :--- |
| Plant water use | Dashboard |
| SPAC Water Potential | Dashboard |
| Irrigation Scheduling | Dashboard |
| Weighing Lysimeter | Dashboard |
| Weather Station (ET) (Evapotranspiration) | Dashboard |
| Weather Station (Fire) | Dashboard |
| Weather Station (Air Quality) | Dashboard |
| Water Quality | Dashboard |
| Soil Measurements | Dashboard or Module |
| Plant Water Use (PWU-E1 or PWU-E2) | Module |
| Plant Water Potential | Module |
| Soil Water Potential | Module |
| Soil Measurements (Multi) | Module |
| SFMx Sap Flow/SDI-12 | Module |
| Plant Health/CWSI | Module |

## Measurement Problem Sensor Combinations (priced without datalogger)

Replacing the SNiPs, these large system combinations are intended to cover most eventualities that we encounter, whilst providing clear answers to the measurement problems that customers present. When quoting a System from the new list, the only thing to change is the -D, -L, -C, -S, or -3P. A -3P will require power system to be designed as this deletes the power option from the rest of the build.
