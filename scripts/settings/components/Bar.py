import customtkinter as ctk

# Import custom widgets
from widgets.config_switch import ConfigSwitch
from widgets.headers import H1, H2
from widgets.navigation_button import NavigationButton
from widgets.tab import Tab
from widgets.config_optionmenu import ConfigOptionMenu
from widgets.config_spinbox import ConfigSpinbox
from widgets.config_radiobutton import ConfigRadiobutton

# Module name for this tab
moduleName = "Bar"


class BarTab(Tab):
    """
    Represents the settings tab for the 'Bar' module.
    Contains various configuration options for bar behavior and appearance.
    """
    def __init__(self, master):
        super().__init__(master, moduleName)
        # Configure column to expand with window
        self.columnconfigure(0, weight=1)

        #################
        # General Bar Settings #
        #################
        # Common packing arguments for widgets
        self.packArgs = {"fill": "x", "padx": (0, 10)}
        # Header for the General section
        self.generalH1 = H1(self, text="General")
        self.generalH1.pack(**self.packArgs)

        # Enabled switch for the bar
        self.enabledSw = ConfigSwitch(
            master=self,
            icon="\uf898",
            text="Enabled",
            hintText="Enable / disable bar",
            key=None,
            default=None,
            changed=None,
        )
        self.enabledSw.pack(**self.packArgs)
        # Autohide switch for the bar
        self.autohideSw = ConfigSwitch(
            master=self,
            icon="\ueb32",
            text="Autohide",
            hintText="Enable / disable autohide bar",
            key=None,
            default=None,
            changed=None,
        )
        self.autohideSw.pack(**self.packArgs)
        # Separated switch for the bar
        self.separatedSw = ConfigSwitch(
            master=self,
            icon="\u10186",
            text="Separated",
            key=None,
            default=None,
            changed=None,
        )
        self.separatedSw.pack(**self.packArgs)
        # Orientation & position radio buttons
        self.orientationBrb = ConfigRadiobutton(
            master=self,
            icon="\ufd36",
            text="Orientation",
            key=None,
            default=None,
            changed=None,
        )
        self.orientationBrb.pack(**self.packArgs)
        # Thickness spinbox
        self.thicknessSb = ConfigSpinbox(
            master=self,
            icon="\uef33",
            text="Thickness",
            hintText="separated bar",
            key=None,
            default=None,
            changed=None,
        )
        self.thicknessSb.pack(**self.packArgs)
        # Long side margin spinbox
        self.longSideMarginSb = ConfigSpinbox(
            master=self,
            icon="\uead5",
            text="Long side margin",
            hintText="",
            key=None,
            default=None,
            changed=None,
        )
        self.longSideMarginSb.pack(**self.packArgs)
        # Short side margin spinbox
        self.shortSideMarginSb = ConfigSpinbox(
            master=self,
            icon="\ueacf",
            text="Short side margin",
            hintText="",
            key=None,
            default=None,
            changed=None,
        )
        self.shortSideMarginSb.pack(**self.packArgs)

        ###########
        # Rounding #
        ###########
        # Header for Rounding settings
        self.roundingH2 = H2(self, text="Rounding")
        self.roundingH2.pack(**self.packArgs)
        # Frame to hold rounding override switches and spinboxes
        self.roundingFrame = ctk.CTkFrame(self, fg_color="transparent")
        self.roundingFrame.columnconfigure(0, weight=1)
        self.roundingFrame.pack(**self.packArgs)

        # All rounding override switch and spinbox
        self.allRoundingOverrideSw = ConfigSwitch(
            master=self.roundingFrame,
            icon="\ufdd3",
            text="all",
            hintText="",
            key=None,
            default=None,
            changed=None,
        )
        self.allRoundingOverrideSw.grid(
            row=0, column=0, padx=self.elemPadX, pady=self.elemPadY, sticky="nsew"
        )
        self.allRoundingOverrideSb = ConfigSpinbox(
            master=self.roundingFrame, key=None, default=None, changed=None
        )
        self.allRoundingOverrideSb.grid(
            row=0, column=1, padx=self.elemPadX, pady=(0, 5), sticky="s"
        )
        # Begin rounding override switch and spinbox
        self.beginRoundingOverrideSw = ConfigSwitch(
            master=self.roundingFrame,
            icon="\ufd29",
            text="begin",
            hintText="",
            key=None,
            default=None,
            changed=None,
        )
        self.beginRoundingOverrideSw.grid(
            row=1, column=0, padx=self.elemPadX, pady=self.elemPadY, sticky="nsew"
        )
        self.beginRoundingOverrideSb = ConfigSpinbox(
            master=self.roundingFrame, key=None, default=None, changed=None
        )
        self.beginRoundingOverrideSb.grid(
            row=1, column=1, padx=self.elemPadX, pady=(0, 5), sticky="s"
        )
        # Center rounding override switch and spinbox
        self.centerRoundingOverrideSw = ConfigSwitch(
            master=self.roundingFrame,
            icon="\ufd2a",
            text="center",
            hintText="",
            key=None,
            default=None,
            changed=None,
        )
        self.centerRoundingOverrideSw.grid(
            row=2, column=0, padx=self.elemPadX, pady=self.elemPadY, sticky="nsew"
        )
        self.centerRoundingOverrideSb = ConfigSpinbox(
            master=self.roundingFrame, key=None, default=None, changed=None
        )
        self.centerRoundingOverrideSb.grid(
            row=2, column=1, padx=self.elemPadX, pady=(0, 5), sticky="s"
        )
        # End rounding override switch and spinbox
        self.endRoundingOverrideSw = ConfigSwitch(
            master=self.roundingFrame,
            icon="\ufd26",
            text="end",
            hintText="",
            key=None,
            default=None,
            changed=None,
        )
        self.endRoundingOverrideSw.grid(
            row=3, column=0, padx=self.elemPadX, pady=self.elemPadY, sticky="nsew"
        )
        self.endRoundingOverrideSb = ConfigSpinbox(
            master=self.roundingFrame, key=None, default=None, changed=None
        )
        self.endRoundingOverrideSb.grid(
            row=3, column=1, padx=self.elemPadX, pady=(0, 5), sticky="s"
        )

        ########################
        # Invert Base Rounding #
        ########################
        # Header for Invert base rounding
        self.ibrH2 = H2(self, text="Invert base rounding")
        self.ibrH2.pack(**self.packArgs)
        # Option menu for all base rounding inversion
        self.allIbrOm = ConfigOptionMenu(
            master=self,
            icon="\ufdd3",
            text="all",
            hintText="",
            key=None,
            default=None,
            changed=None,
        )
        self.allIbrOm.pack(**self.packArgs)
        # Option menu for begin base rounding inversion
        self.beginIbrOm = ConfigOptionMenu(
            master=self,
            icon="\ufd29",
            text="begin",
            hintText="",
            key=None,
            default=None,
            changed=None,
        )
        self.beginIbrOm.pack(**self.packArgs)
        # Option menu for center base rounding inversion
        self.centerIbrOm = ConfigOptionMenu(
            master=self,
            icon="\ufd2a",
            text="center",
            hintText="",
            key=None,
            default=None,
            changed=None,
        )
        self.centerIbrOm.pack(**self.packArgs)
        # Option menu for end base rounding inversion
        self.endIbrOm = ConfigOptionMenu(
            master=self,
            icon="\ufd26",
            text="end",
            hintText="",
            key=None,
            default=None,
            changed=None,
        )
        self.endIbrOm.pack(**self.packArgs)

        #############
        # Reusability #
        #############
        # Header for Reusability settings
        self.reusabilityH2 = H2(self, text="Reusability")
        self.reusabilityH2.pack(**self.packArgs)
        # Option menu for all reusability
        self.allReusabilityOm = ConfigOptionMenu(
            master=self,
            icon="\ufdd3",
            text="all",
            hintText="",
            key=None,
            default=None,
            changed=None,
        )
        self.allReusabilityOm.pack(**self.packArgs)
        # Option menu for begin reusability
        self.beginReusabilityOm = ConfigOptionMenu(
            master=self,
            icon="\ufd29",
            text="begin",
            hintText="",
            key=None,
            default=None,
            changed=None,
        )
        self.beginReusabilityOm.pack(**self.packArgs)
        # Option menu for center reusability
        self.centerReusabilityOm = ConfigOptionMenu(
            master=self,
            icon="\ufd2a",
            text="center",
            hintText="",
            key=None,
            default=None,
            changed=None,
        )
        self.centerReusabilityOm.pack(**self.packArgs)
        # Option menu for end reusability
        self.endReusabilityOm = ConfigOptionMenu(
            master=self,
            icon="\ufd26",
            text="end",
            hintText="",
            key=None,
            default=None,
            changed=None,
        )
        self.endReusabilityOm.pack(**self.packArgs)


class BarNavigationButton(NavigationButton):
    """
    Navigation button specific to the Bar module.
    """
    def __init__(self, master, command):
        super().__init__(master, icon="\uf647", text=moduleName, command=command)
