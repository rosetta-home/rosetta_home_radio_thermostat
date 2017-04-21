defmodule Cicada.DeviceManager.Device.HVAC.RadioThermostat do
  use Cicada.DeviceManager.DeviceHistogram
  require Logger
  alias Cicada.{DeviceManager}
  @behaviour Cicada.DeviceManager.Behaviour.HVAC

  def start_link(id, %{device: %{device_type: "com.marvell.wm.system:1.0"}} = device) do
    GenServer.start_link(__MODULE__, {id, device}, name: id)
  end

  def fan_on(pid) do
    GenServer.call(pid, :on)
  end

  def fan_off(pid) do
    GenServer.call(pid, :off)
  end

  @spec set_temp(pid, number) :: boolean
  def set_temp(pid, temp) do
    GenServer.call(pid, {:set_temp, temp})
  end

  def device(pid) do
    GenServer.call(pid, :device)
  end

  def update_state(pid, state) do
    GenServer.call(pid, {:update, state})
  end

  def get_id(device) do
    :"RadioThermostat-#{device.device.serial_number}"
  end

  def map_state({:ok, state}) do
    %DeviceManager.Device.HVAC.State{
      temperature: state["temp"],
      fan_mode: state["fmode"] |> fmode,
      fan_state: state["fstate"] |> fstate,
      temporary_target_cool: state |> Map.get("t_cool", 0),
      temporary_target_heat: state |> Map.get("t_heat", 0),
      mode: state["tmode"] |> tmode,
      state: state["tstate"] |> tstate,
    }
  end

  def tstate(val) do
    case val do
      0 -> :off
      1 -> :heat
      2 -> :cool
    end
  end

  def tmode(val) do
    case val do
      0 -> :off
      1 -> :heat
      2 -> :cool
      3 -> :auto
    end
  end

  def fmode(val) do
    case val do
      0 -> :auto
      1 -> :auto_circulate
      2 -> :on
    end
  end

  def fstate(val) do
    case val do
      0 -> :off
      1 -> :on
    end
  end

  def init({id, device}) do
    {:ok, pid} = RadioThermostat.start_link(device.url)
    Process.send_after(self(), :update_state, 0)
    r_state = RadioThermostat.state(pid) |> map_state
    {:ok, %DeviceManager.Device{
      module: RadioThermostat,
      type: :hvac,
      device_pid: pid,
      interface_pid: id,
      name: device.device.friendly_name,
      state: r_state
    }}
  end

  def handle_info(:update_state, device) do
    device = %DeviceManager.Device{device | state:
      RadioThermostat.state(device.device_pid) |> map_state
    } |> DeviceManager.dispatch
    Process.send_after(self(), :update_state, 13000)
    {:noreply, device}
  end

  def handle_call({:update, _state}, _from, device) do
    {:reply, device.state, device}
  end

  def handle_call(:device, _from, device) do
    {:reply, device, device}
  end

  def handle_call(:on, _from, device) do
    {:reply,
      case RadioThermostat.set(device.device_pid, :fan, 1) do
        {:ok, %{"success": 0}} ->
          Process.send_after(self(), :update_state, 0)
          true
        other ->
          IO.inspect other
          false
      end, device}
  end

  def handle_call(:off, _from, device) do
    {:reply,
      case RadioThermostat.set(device.device_pid, :fan, 0) do
        {:ok, %{"success": 0}} ->
          Process.send_after(self(), :update_state, 0)
          true
        other ->
          IO.inspect other
          false
      end, device}
  end

  def handle_call({:set_temp, temp}, _from, device) do
    case device.state.mode do
      :cool ->
        case temp > device.state.temperature do
          true -> RadioThermostat.set(device.device_pid, :temporary_heat, temp)
          false -> RadioThermostat.set(device.device_pid, :temporary_cool, temp)
        end
      :heat ->
        case temp < device.state.temperature do
          true -> RadioThermostat.set(device.device_pid, :temporary_cool, temp)
          false -> RadioThermostat.set(device.device_pid, :temporary_heat, temp)
        end
    end
    Process.send_after(self(), :update_state, 1000)
    {:reply, :ok, device}
  end

end

defmodule Cicada.DeviceManager.Discovery.HVAC.RadioThermostat do
  require Logger
  alias Cicada.DeviceManager.Device.HVAC
  use Cicada.DeviceManager.Discovery, module: HVAC.RadioThermostat

  def register_callbacks do
    Logger.info "Starting RadioThermostat Listener"
    SSDP.register
    %{}
  end

  def handle_info({:device, %{device: %{device_type: "com.marvell.wm.system:1.0"}} = device}, state) do
    {:noreply, handle_device(device, state)}
  end

  def handle_info({:device, device}, state) do
    {:noreply, state}
  end

end
