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
        marker: {
          show: false
        },
        custom: ({ series, seriesIndex, dataPointIndex, w }) => {
          const value = series[seriesIndex][dataPointIndex]
          const timestamp = w.globals.seriesX[seriesIndex][dataPointIndex]
          const date = new Date(timestamp)
          const day = date.getDate()
          const month = date.toLocaleString("en-US", { month: "short" })
          return `<div style="padding:4px 8px;line-height:1.1;">
                    <div style="font-size:12px;font-weight:600;">€${value.toFixed(2)}</div>
                    <div style="font-size:9px;color:#888;">${day}/${month}</div>
                  </div>`
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
