import { Controller } from "@hotwired/stimulus"
import ApexCharts from "apexcharts"

export default class extends Controller {
  static values = {
    data: Array
  }

  connect() {
    if (this.dataValue.length === 0) return

    const options = {
      series: [{
        name: "Price",
        data: this.dataValue
      }],
      chart: {
        type: "line",
        height: 40,
        width: 150,
        sparkline: {
          enabled: true
        },
        animations: {
          enabled: false
        }
      },
      stroke: {
        curve: "smooth",
        width: 2
      },
      colors: ["#36d399"],
      tooltip: {
        enabled: true,
        fixed: {
          enabled: false
        },
        x: {
          show: false
        },
        y: {
          formatter: (value) => `€${value.toFixed(2)}`,
          title: {
            formatter: () => ""
          }
        },
        marker: {
          show: false
        }
      }
    }

    this.chart = new ApexCharts(this.element, options)
    this.chart.render()
  }

  disconnect() {
    if (this.chart) {
      this.chart.destroy()
    }
  }
}
