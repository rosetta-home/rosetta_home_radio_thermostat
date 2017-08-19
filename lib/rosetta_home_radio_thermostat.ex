defmodule Cicada.DeviceManager.Device.HVAC.RadioThermostat do
  use Cicada.DeviceManager.DeviceHistogram
  require Logger
  alias Cicada.{DeviceManager}
  @behaviour Cicada.DeviceManager.Behaviour.HVAC

  def start_link(id, %{device: %{device_type: "com.marvell.wm.system:1.0"}} = device) do
    GenServer.start_link(__MODULE__, {id, device}, name: id)
  end

  def fan_on(pid) do
    GenServer.call(pid, :fan_on)
  end

  def fan_off(pid) do
    GenServer.call(pid, :fan_off)
  end

  def hold_on(pid) do
    GenServer.call(pid, :hold_on)
  end

  def hold_off(pid) do
    GenServer.call(pid, :hold_off)
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
    {:ok, %DeviceManager.Device{
      module: __MODULE__,
      type: :hvac,
      device_pid: pid,
      interface_pid: id,
      name: device.device.friendly_name,
      state: %DeviceManager.Device.HVAC.State{}
    }}
  end

  def handle_info(:update_state, device) do
    RadioThermostat.state(device.device_pid)
    Process.send_after(self(), :update_state, 10_000)
    {:noreply, device}
  end

  def handle_info({:state, :ok, state}, device) do
    now = :erlang.monotonic_time(:seconds)
    device_now = {:ok, state} |> map_state()
    current_state = device.state.state
    last_update = device.state.last_update
    {last_update, elapsed} =
      case device_now.state do
        current_state when last_update == 0 -> {now, 0}
        current_state -> {now, device.state.elapsed + (now - device.state.last_update)}
        _ -> {now, 0}
      end
    {:noreply, %DeviceManager.Device{device |
      state: %DeviceManager.Device.HVAC.State{device_now |
        last_update: last_update,
        elapsed: elapsed
      }
    } |> DeviceManager.dispatch}
  end

  def handle_info({resource, :ok, resp}, state) do
    Logger.debug("#{resource} ok: #{inspect resp}")
    {:noreply, state}
  end

  def handle_info({resource, :error, reason}, state) do
    Logger.error("#{resource} error: #{inspect reason}")
    {:noreply, state}
  end

  def handle_call({:update, _state}, _from, device) do
    {:reply, device.state, device}
  end

  def handle_call(:device, _from, device) do
    {:reply, device, device}
  end

  def handle_call(:fan_on, _from, device) do
    {:reply, :fan |> do_call(:on, device), device}
  end

  def handle_call(:fan_off, _from, device) do
    {:reply, :fan |> do_call(:off, device), device}
  end

  def handle_call(:hold_on, _from, device) do
    {:reply, :hold |> do_call(:on, device), device}
  end

  def handle_call(:hold_off, _from, device) do
    {:reply, :hold |> do_call(:off, device), device}
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
    {:reply, :ok, device}
  end

  defp do_call(resource, state, device) do
    RadioThermostat.set(device.device_pid, resource, state)
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
